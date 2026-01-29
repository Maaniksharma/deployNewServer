FROM ubuntu:22.04

# Install basic dependencies ensuring we can run the script and basic debug tools
RUN apt-get update && apt-get install -y \
    sudo \
    curl \
    gnupg \
    ca-certificates \
    lsb-release \
    vim \
    git \
    ssh \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the script
COPY script.sh .

# Make it executable
RUN chmod +x script.sh

# Default command
CMD ["/bin/bash"]
