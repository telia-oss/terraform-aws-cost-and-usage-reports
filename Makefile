DIST_PATH	 := $(CURDIR)/dist
DOCKER_PATH	 := $(CURDIR)/docker
DOCKER_IMAGE := amazonlinux
DOCKER_TAG	 := 2016.09

default: test

test:
	@echo "== Test =="
	@if ! terraform fmt -write=false -check=true >> /dev/null; then \
		echo "✗ terraform fmt failed: $$d"; \
		exit 1; \
	else \
		echo "√ terraform fmt"; \
	fi

	@for d in $$(find . -type f -name '*.tf' -path "./modules/*" -not -path "**/.terraform/*" -exec dirname {} \; | sort -u); do \
		cd $$d; \
		terraform init -backend=false >> /dev/null; \
		terraform validate -check-variables=false; \
		if [ $$? -eq 1 ]; then \
			echo "✗ terraform validate failed: $$d"; \
			exit 1; \
		fi; \
		cd $(CURDIR); \
	done
	@echo "√ terraform validate modules (not including variables)"; \

	@for d in $$(find . -type f -name '*.tf' -path "./examples/*" -not -path "**/.terraform/*" -exec dirname {} \; | sort -u); do \
		cd $$d; \
		terraform init -backend=false >> /dev/null; \
		terraform validate; \
		if [ $$? -eq 1 ]; then \
			echo "✗ terraform validate failed: $$d"; \
			exit 1; \
		fi; \
		cd $(CURDIR); \
	done
	@echo "√ terraform validate examples"; \

	@for d in $$(find . -type f -name '*.py' -path "./src/*" -exec dirname {} \; | sort -u); do \
		cd $$d; \
		pylint *.py; \
		if [ $$? -ne 0 ]; then \
			echo "✗ pylint failed: $$d"; \
			exit 1; \
		fi; \
		cd $(CURDIR); \
	done
	@echo "√ pylint code"; \

build: clean test build-environment build-csv-processor build-manifest-processor build-bucket-forwarder

build-environment:
	@echo "== Building environment =="
	mkdir -p dist
	docker run -v $(PWD):/source -it $(DOCKER_IMAGE):$(DOCKER_TAG) /bin/bash source/docker/build.sh
	@echo "√ Lambda environment built"

build-csv-processor:
	@echo "== Build csv-processor =="
	@if ! test -d "$(DIST_PATH)"; then echo "Environment not created, run 'make build-environment' first"; exit 1; fi
	zip -9 -j -O $(DIST_PATH)/csv_processor.zip $(DIST_PATH)/environment.zip src/csv_processor/lambda.py
	@echo "√ csv processor release built"

build-manifest-processor:
	@echo "== Build manifest-processor release =="
	zip -9 -j $(DIST_PATH)/manifest_processor.zip src/manifest_processor/lambda.py
	@echo "√ manifest processor release built"

build-bucket-forwarder:
	@echo "== Build bucket-forwarder =="
	zip -9 -j $(DIST_PATH)/bucket_forwarder.zip src/bucket_forwarder/lambda.py
	@echo "√ bucket forwarder release built"

upload-lambda-billing-account:
	@echo "== Uploading bucket_forwarder.zip =="
	@if test -z "$(BUCKET)"; then echo "BUCKET variable not set"; exit 1; fi
	aws s3 cp $(DIST_PATH)/bucket_forwarder.zip s3://$(BUCKET)/lambda/bucket_forwarder.zip
	@echo "√ bucket_forwarder.zip uploaded"

upload-lambda-processing-account:
	@echo "== Uploading csv_processor.zip and manifest_processor.zip =="
	@if test -z "$(BUCKET)"; then echo "BUCKET variable not set"; exit 1; fi
	aws s3 cp $(DIST_PATH)/csv_processor.zip s3://$(BUCKET)/lambda/csv_processor.zip
	aws s3 cp $(DIST_PATH)/manifest_processor.zip s3://$(BUCKET)/lambda/manifest_processor.zip
	@echo "√ csv_processor.zip and manifest_processor.zip uploaded"

clean:
	@echo "== Cleaning dist =="
	rm -rf dist
	@echo "√ dist removed"

.PHONY: default test build build-environment build-csv-processor build-manifest-processor build-bucket-forwarder upload-lambda-billing-account upload-lambda-processing-account
