# Produce Android App Bundle
flutter build appbundle --release

# Deploy Firebase Web App
flutter build web

firebase deploy --only hosting --project trippy-prod-4524f

# Generate Personal Access Token (PAT) for AI Bots (Grok, Gemini, ChatGPT)
dart run bin/create_pat.dart --email roljs@hotmail.com --name "Grok Bot"

# Deploy MCP Server (Powered by Firestore Personal Access Tokens)
gcloud run deploy trippy-mcp-server --source . --region us-central1 --port 8080 --project trippy-prod-4524f --allow-unauthenticated --set-env-vars TRIPPY_PROJECT_ID=trippy-prod-4524f

**Note:** Personal Access Tokens created via `create_pat.dart` or MCP tools are stored in Cloud Firestore (`mcp_api_keys` collection). They work dynamically in real time without requiring you to re-deploy Cloud Run or manage token environment variables.