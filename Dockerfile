# Stage 1: Official Google Dart SDK build environment
FROM dart:stable AS build

WORKDIR /app

# Create a clean pubspec with only the dependencies required by the MCP server
RUN printf "name: trippy\nenvironment:\n  sdk: '>=3.13.0 <4.0.0'\ndependencies:\n  uuid: ^4.6.0\n  crypto: ^3.0.3\n" > pubspec.yaml

# Download pure-Dart dependencies
RUN dart pub get

# Copy the server entrypoint, service, and pure-Dart data models
COPY bin/ ./bin/
COPY lib/mcp/ ./lib/mcp/
COPY lib/models/ ./lib/models/
COPY lib/core/utils/airport_timezone_helper.dart ./lib/core/utils/airport_timezone_helper.dart
COPY sample_trip.json ./

# Compile standalone native Linux executable
RUN dart compile exe bin/trippy_mcp_server.dart -o /app/trippy_mcp_server

# Stage 2: Minimal runtime image for Google Cloud Run
FROM debian:bookworm-slim

# Install CA certificates for outgoing HTTPS calls
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the compiled standalone executable and sample data seed
COPY --from=build /app/trippy_mcp_server /app/trippy_mcp_server
COPY --from=build /app/sample_trip.json /app/sample_trip.json

# Cloud Run injects PORT (defaults to 8080)
ENV PORT=8080
ENV TRIPPY_PROJECT_ID=trippy-prod-4524f

EXPOSE 8080

ENTRYPOINT ["/app/trippy_mcp_server"]
