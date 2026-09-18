#!/usr/bin/env python3
import os
import sys
import re
import argparse
import subprocess

# Attempt to import bcrypt; if missing, print help on installing it
try:
    import bcrypt
except ImportError:
    print("Error: The 'bcrypt' Python library is required.")
    print("Please install it by running: pip install bcrypt")
    sys.exit(1)

def load_env(env_path):
    env_vars = {}
    if not os.path.exists(env_path):
        # Fall back to alternative paths if not found directly
        paths_to_try = [env_path, "backend/.env", ".env"]
        found = False
        for p in paths_to_try:
            if os.path.exists(p):
                env_path = p
                found = True
                break
        if not found:
            print(f"Error: Environment file not found at {env_path}")
            sys.exit(1)
            
    with open(env_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if '=' in line:
                key, val = line.split('=', 1)
                env_vars[key.strip()] = val.strip()
    return env_vars

def parse_jdbc_url(jdbc_url):
    # Format: jdbc:postgresql://host:port/database
    match = re.match(r'jdbc:postgresql://([^/:]+)(?::(\d+))?/([^?]+)', jdbc_url)
    if not match:
        print(f"Error: Invalid JDBC URL format: {jdbc_url}")
        sys.exit(1)
    host = match.group(1)
    port = match.group(2) or '5432'
    dbname = match.group(3).split('?')[0]  # Strip any connection parameters
    return host, port, dbname

def execute_sql(env, query, params=None):
    db_url = env.get('SPRING_DATASOURCE_URL')
    user = env.get('SPRING_DATASOURCE_USERNAME', 'postgres')
    password = env.get('SPRING_DATASOURCE_PASSWORD', '')

    if not db_url:
        print("Error: SPRING_DATASOURCE_URL not found in .env")
        sys.exit(1)

    host, port, dbname = parse_jdbc_url(db_url)

    # Set password for psql
    os.environ['PGPASSWORD'] = password

    # Construct psql command
    cmd = ['psql', '-h', host, '-p', port, '-U', user, '-d', dbname, '-Atc', query]
    
    if params:
        escaped_params = []
        for p in params:
            if isinstance(p, str):
                escaped_params.append("'" + p.replace("'", "''") + "'")
            elif p is None:
                escaped_params.append("NULL")
            else:
                escaped_params.append(str(p))
        query = query % tuple(escaped_params)
        cmd[-1] = query

    try:
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        return result.stdout.strip(), None
    except subprocess.CalledProcessError as e:
        return None, e.stderr.strip()

def hash_password(password):
    # Hash password with BCrypt (rounds=10) matching Spring Security Encoder
    salt = bcrypt.gensalt(10)
    hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
    return hashed.decode('utf-8')

def find_user(env, identifier):
    query = "SELECT id, email, username, plan_type, subscription_status, role FROM users WHERE email = %s OR username = %s LIMIT 1"
    output, err = execute_sql(env, query, (identifier, identifier))
    if err:
        print(f"Error querying database: {err}")
        return None
    if not output:
        return None
    
    parts = output.split('|')
    if len(parts) < 6:
         return None
    return {
        'id': parts[0],
        'email': parts[1],
        'username': parts[2],
        'plan_type': parts[3],
        'subscription_status': parts[4],
        'role': parts[5]
    }

def delete_user(env, user_id):
    # Order matters because of Foreign Key constraints
    queries = [
        ("DELETE FROM otp_verifications WHERE user_id = %s", (user_id,)),
        ("DELETE FROM speech_to_text_requests WHERE user_id = %s", (user_id,)),
        ("DELETE FROM tts_history WHERE user_id = %s", (user_id,)),
        ("DELETE FROM payments WHERE user_id = %s", (user_id,)),
        ("DELETE FROM subscriptions WHERE user_id = %s", (user_id,)),
        ("DELETE FROM users WHERE id = %s", (user_id,))
    ]
    for q, p in queries:
        _, err = execute_sql(env, q, p)
        if err:
            return err
    return None

def create_user(env, username, email, phone, raw_password, plan="FREE", role="USER"):
    # Generate next ID from the sequence
    seq_query = "SELECT nextval('users_seq')"
    seq_output, err = execute_sql(env, seq_query)
    if err or not seq_output:
        return None, f"Failed to generate sequence ID: {err}"
    
    user_id = int(seq_output)
    hashed = hash_password(raw_password)
    
    insert_query = (
        "INSERT INTO users (id, username, email, phone_number, password, plan_type, "
        "subscription_status, role, is_active, email_verified, account_status, "
        "consent_accepted, session_version, version, created_at, updated_at) "
        "VALUES (%s, %s, %s, %s, %s, %s, 'ACTIVE', %s, true, true, 'ACTIVE', true, 1, 0, "
        "CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
    )
    _, err = execute_sql(env, insert_query, (user_id, username, email, phone, hashed, plan, role))
    if err:
        return None, err
    return user_id, None

def run_create_flow(env, username=None, email=None, phone=None, password=None, plan=None, role=None):
    print("\n=== Create New User ===")
    if not username:
        username = input("Enter Username: ").strip()
    if not email:
        email = input("Enter Email: ").strip()
    if not phone:
        phone = input("Enter Phone Number: ").strip()
    if not password:
        password = input("Enter Password: ").strip()
        
    if not plan:
        print("\nSelect Plan:")
        print("1) FREE (Default)")
        print("2) PRO")
        print("3) PRO_PLUS")
        print("4) ENTERPRISE")
        p_choice = input("Choice (1-4): ").strip()
        plan = {'1': 'FREE', '2': 'PRO', '3': 'PRO_PLUS', '4': 'ENTERPRISE'}.get(p_choice, 'FREE')
        
    if not role:
        print("\nSelect Role:")
        print("1) USER (Default)")
        print("2) ADMIN")
        r_choice = input("Choice (1-2): ").strip()
        role = {'1': 'USER', '2': 'ADMIN'}.get(r_choice, 'USER')

    if not username or not email or not phone or not password:
        print("[-] Error: Username, Email, Phone, and Password cannot be empty.")
        return

    # Check duplication
    existing = find_user(env, username) or find_user(env, email)
    if existing:
        print(f"[-] Error: A user with username or email '{username}/{email}' already exists.")
        return

    print("\n[*] Creating user account...")
    uid, err = create_user(env, username, email, phone, password, plan, role)
    if err:
        print(f"[-] Failed to create user: {err}")
    else:
        print(f"[+] User created successfully with ID: {uid}!")

def main():
    parser = argparse.ArgumentParser(description="SpeakIT Dev User Management Script")
    parser.add_argument("--env", default="backend/.env", help="Path to backend .env file")
    parser.add_argument("--user", help="Email or Username of the target user")
    parser.add_argument("--info", action="store_true", help="Print user details")
    parser.add_argument("--create", action="store_true", help="Create a new user")
    parser.add_argument("--delete", action="store_true", help="Delete a user")
    parser.add_argument("--reset-password", metavar="NEW_PASSWORD", help="Reset password for the user")
    parser.add_argument("--set-plan", choices=["FREE", "PRO", "PRO_PLUS", "ENTERPRISE"], help="Upgrade/Downgrade the user plan")
    
    args = parser.parse_args()

    # Load environment configuration
    env = load_env(args.env)

    # CLI Explicit Create Flow
    if args.create:
        run_create_flow(env)
        sys.exit(0)

    # Interactive Main Menu if no CLI arguments are supplied
    if not args.user and not args.delete:
        print("=== SpeakIT User Management Console ===")
        print("1) Search & Manage Existing User")
        print("2) Create New User")
        print("3) Exit")
        choice = input("Enter choice (1-3): ").strip()
        if choice == '2':
            run_create_flow(env)
            sys.exit(0)
        elif choice == '1':
            args.user = input("\nEnter user Email or Username to search: ").strip()
            if not args.user:
                print("Username/Email cannot be empty.")
                sys.exit(1)
        else:
            print("Exiting.")
            sys.exit(0)

    # Lookup user
    user_data = find_user(env, args.user)
    if not user_data:
        print(f"\n[-] User '{args.user}' not found in the database.")
        sys.exit(1)

    print(f"\n[+] User Found:")
    print(f"    - ID:                  {user_data['id']}")
    print(f"    - Username:            {user_data['username']}")
    print(f"    - Email:               {user_data['email']}")
    print(f"    - Current Plan:        {user_data['plan_type']}")
    print(f"    - Subscription Status: {user_data['subscription_status']}")
    print(f"    - Role:                {user_data['role']}")

    if args.info and not args.reset_password and not args.set_plan and not args.delete:
        sys.exit(0)

    # CLI Explicit Delete Flow
    if args.delete:
        confirm = input(f"\n[!] WARNING: Are you sure you want to permanently delete user '{user_data['username']}' and all their subscriptions/payments? (y/N): ").strip().lower()
        if confirm == 'y':
            print("[*] Deleting user data...")
            err = delete_user(env, user_data['id'])
            if err:
                print(f"[-] Deletion failed: {err}")
            else:
                print("[+] User deleted successfully!")
        else:
            print("Operation cancelled.")
        sys.exit(0)

    # If no action arguments are provided, ask interactively
    action = None
    if not args.reset_password and not args.set_plan:
        print("\nChoose an action:")
        print("1) Reset Password")
        print("2) Upgrade/Downgrade Plan")
        print("3) Delete User Account")
        print("4) Cancel")
        choice = input("Enter choice (1-4): ").strip()
        if choice == '1':
            action = 'reset-password'
        elif choice == '2':
            action = 'set-plan'
        elif choice == '3':
            action = 'delete'
        else:
            print("Operation cancelled.")
            sys.exit(0)
    elif args.reset_password:
        action = 'reset-password'
    elif args.set_plan:
        action = 'set-plan'

    if action == 'reset-password':
        new_password = args.reset_password
        if not new_password:
            new_password = input("Enter new password: ").strip()
            if not new_password:
                print("Password cannot be empty.")
                sys.exit(1)

        print("\n[*] Hashing password with BCrypt...")
        hashed = hash_password(new_password)
        
        print("[*] Updating database...")
        query = "UPDATE users SET password = %s, session_version = session_version + 1 WHERE id = %s"
        _, err = execute_sql(env, query, (hashed, user_data['id']))
        if err:
            print(f"[-] Failed to update password: {err}")
        else:
            print("[+] Password reset successfully!")

    elif action == 'set-plan':
        plan = args.set_plan
        if not plan:
            print("\nSelect target plan:")
            print("1) FREE")
            print("2) PRO")
            print("3) PRO_PLUS")
            print("4) ENTERPRISE")
            choice = input("Enter choice (1-4): ").strip()
            plan_map = {'1': 'FREE', '2': 'PRO', '3': 'PRO_PLUS', '4': 'ENTERPRISE'}
            plan = plan_map.get(choice)
            if not plan:
                print("Invalid plan selection.")
                sys.exit(1)

        print(f"\n[*] Updating user plan to {plan}...")
        query = "UPDATE users SET plan_type = %s, subscription_status = 'ACTIVE', plan_expiry = NULL, session_version = session_version + 1 WHERE id = %s"
        _, err = execute_sql(env, query, (plan, user_data['id']))
        if err:
            print(f"[-] Failed to update plan: {err}")
        else:
            print(f"[+] Plan updated to {plan} successfully (forced session refresh)!")

    elif action == 'delete':
        confirm = input(f"\n[!] WARNING: Are you sure you want to permanently delete user '{user_data['username']}' and all their subscriptions/payments? (y/N): ").strip().lower()
        if confirm == 'y':
            print("[*] Deleting user data...")
            err = delete_user(env, user_data['id'])
            if err:
                print(f"[-] Deletion failed: {err}")
            else:
                print("[+] User deleted successfully!")
        else:
            print("Operation cancelled.")

if __name__ == "__main__":
    main()
