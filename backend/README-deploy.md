Backend deployment notes

Recommended hosts: Render, Heroku, Railway. Vercel is not recommended for long-running JVM apps.

- Render (quick):
  - Push repo to GitHub.
  - Create a new Web Service on Render and connect the repo; point the service to the `backend` folder.
  - Build command: `mvn -DskipTests package`
  - Start command: `java -jar target/*.jar`
  - Set environment variables `cors.allowed-origins` (e.g. `https://your-frontend.vercel.app`) and any AWS credentials.

- Heroku (quick):
  - Add `Procfile` (already provided), push to Heroku remote, set Config Vars via dashboard.

- Docker: Use the provided `Dockerfile` to build and run.

CORS:
- The backend reads `cors.allowed-origins` from `application.properties` or environment. Set it to your frontend origin in production (e.g. `https://your-site.vercel.app`).
