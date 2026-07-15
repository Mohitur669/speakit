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

def main():
    parser = argparse.ArgumentParser(description="SpeakIT Dev User Management Script")
    parser.add_argument("--env", default="backend/.env", help="Path to backend .env file")
    parser.add_argument("--user", help="Email or Username of the target user")
    parser.add_argument("--reset-password", metavar="NEW_PASSWORD", help="Reset password for the user")
    parser.add_argument("--set-plan", choices=["FREE", "PRO", "PRO_PLUS", "ENTERPRISE"], help="Upgrade/Downgrade the user plan")
    parser.add_argument("--info", action="store_true", help="Print user details")
    
    args = parser.parse_args()

    # Load environment configuration
    env = load_env(args.env)

    # Interactive mode if no user is specified
    if not args.user:
        print("=== SpeakIT User Management Console ===")
        args.user = input("Enter user Email or Username: ").strip()
        if not args.user:
            print("Username/Email cannot be empty.")
            sys.exit(1)

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

    if args.info and not args.reset_password and not args.set_plan:
        sys.exit(0)

    # If no action arguments are provided, ask interactively
    action = None
    if not args.reset_password and not args.set_plan:
        print("\nChoose an action:")
        print("1) Reset Password")
        print("2) Upgrade/Downgrade Plan")
        print("3) Cancel")
        choice = input("Enter choice (1-3): ").strip()
        if choice == '1':
            action = 'reset-password'
        elif choice == '2':
            action = 'set-plan'
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

if __name__ == "__main__":
    main()
