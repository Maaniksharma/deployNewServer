#!/bin/bash

echo "🐳 Building Docker image..."
docker build -t deploy-test .

echo "🚀 Starting interactive test container..."
echo "👉 Inside the container, run: ./script.sh"
echo "------------------------------------------------"

# Mount the current directory's script.sh to /app/script.sh so changes are live
docker run -it --rm --privileged \
  -v "$(pwd)/script.sh:/app/script.sh" \
  deploy-test
