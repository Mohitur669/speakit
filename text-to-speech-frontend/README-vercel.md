Vercel deployment notes

- Build (local):
  - Ensure `API_URL` env var is set when building for production so the runtime script is generated.
    ```bash
    API_URL=https://your-backend.example.com npm run vercel-build
    ```

- Vercel CLI (deploy from this folder):
  ```bash
  cd text-to-speech-frontend
  npm i
  vercel --prod
  ```
  When prompted, set the Output Directory to `dist/text-to-speech-frontend`.

- Alternatively set `API_URL` in the Vercel dashboard (Project → Settings → Environment Variables) and use the `vercel-build` command from the dashboard build step.
