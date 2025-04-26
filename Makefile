# Makefile

# Variables (override via 'make VAR=value')
ROLE_NAME ?= lambda-basic-exec
FUNC_NAME ?= aiChatbotProxy
ZIP        ?= function.zip
ARCH       ?= x86_64-unknown-linux-gnu
ACCOUNT    ?= 123456789012
REGION     ?= us-west-2

# Detect build tool: use 'cross' if available, else 'cargo'
BUILD := $(if $(shell command -v cross), cross, cargo)

# Select build command depending on tool
ifeq ($(BUILD),cross)
BUILD_CMD = cross build --release --target $(ARCH)
else
BUILD_CMD = cargo build --release --target $(ARCH)
endif

# Binary and archive names
BINARY  := ai_chatbot_proxy
ARCHIVE := bootstrap

.PHONY: help init deploy update

help:
	@echo "Usage: make [target] [VARIABLE=value]"
	@echo ""
	@echo "Targets:"
	@echo "  help    Show this help message"
	@echo "  init    Create IAM role if missing"
	@echo "  deploy  Initialize and deploy the Lambda function"
	@echo "  update  Build and update the Lambda function code"
	@echo ""
	@echo "Variables (override defaults):"
	@echo "  ROLE_NAME    IAM role name (default: $(ROLE_NAME))"
	@echo "  FUNC_NAME    Lambda function name (default: $(FUNC_NAME))"
	@echo "  ZIP          Zip file name (default: $(ZIP))"
	@echo "  ARCH         Rust target architecture (default: $(ARCH))"
	@echo "  ACCOUNT      AWS account ID (default: $(ACCOUNT))"
	@echo "  REGION       AWS region (default: $(REGION))"

init:
	@echo "Ensuring trust-policy.json exists..."
	@if [ ! -f trust-policy.json ]; then \
		printf '%s\n' '{' \
		'  "Version": "2012-10-17",' \
		'  "Statement": [' \
		'    {' \
		'      "Effect": "Allow",' \
		'      "Principal": { "Service": "lambda.amazonaws.com" },' \
		'      "Action": "sts:AssumeRole"' \
		'    }' \
		'  ]' \
		'}' > trust-policy.json; \
		echo "Created trust-policy.json"; \
	fi

	@echo "Creating IAM role if missing..."
	@if ! aws iam get-role --role-name $(ROLE_NAME) > /dev/null 2>&1; then \
		aws iam create-role --role-name $(ROLE_NAME) \
		  --assume-role-policy-document file://trust-policy.json; \
		aws iam attach-role-policy --role-name $(ROLE_NAME) \
		  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole; \
	else \
		echo "Role $(ROLE_NAME) already exists."; \
	fi

deploy: init
	@echo "Building and packaging..."
	# Add Rust target if missing
	@if ! rustup target list --installed | grep -q "^$(ARCH)$$"; then \
		rustup target add $(ARCH); \
	fi
	# Build using BUILD_CMD
	$(BUILD_CMD)
	cp target/$(ARCH)/release/$(BINARY) $(ARCHIVE)
	zip -j $(ZIP) $(ARCHIVE)

	@echo "Creating Lambda function..."
	aws lambda create-function \
	  --function-name $(FUNC_NAME) \
	  --runtime provided.al2 \
	  --role arn:aws:iam::$(ACCOUNT):role/$(ROLE_NAME) \
	  --handler $(ARCHIVE) \
	  --zip-file fileb://$(ZIP) \
	  --architectures x86_64 \
	  --region $(REGION)
	@echo "Deployment complete."

update:
	@echo "Building and packaging..."
	# Add Rust target if missing
	@if ! rustup target list --installed | grep -q "^$(ARCH)$$"; then \
		rustup target add $(ARCH); \
	fi
	# Build using BUILD_CMD
	$(BUILD_CMD)
	cp target/$(ARCH)/release/$(BINARY) $(ARCHIVE)
	zip -j $(ZIP) $(ARCHIVE)

	@echo "Updating Lambda function code..."
	aws lambda update-function-code \
	  --function-name $(FUNC_NAME) \
	  --zip-file fileb://$(ZIP)
	@echo "Update complete."