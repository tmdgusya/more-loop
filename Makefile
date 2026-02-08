PREFIX ?= $(HOME)/.local
BIN_DIR = $(PREFIX)/bin
SKILLS_DIR = $(HOME)/.claude/skills
DATA_DIR = $(HOME)/.local/share/more-loop
REPO_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.PHONY: install uninstall link unlink help

help: ## Show this help
	@grep -E '^[a-z]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*## /\t/'

install: ## Copy more-loop binary and skills
	mkdir -p $(BIN_DIR)
	cp $(REPO_DIR)more-loop $(BIN_DIR)/more-loop
	chmod +x $(BIN_DIR)/more-loop
	mkdir -p $(SKILLS_DIR)/more-loop-prompt $(SKILLS_DIR)/more-loop-verify
	cp $(REPO_DIR).claude/skills/more-loop-prompt/SKILL.md $(SKILLS_DIR)/more-loop-prompt/SKILL.md
	cp $(REPO_DIR).claude/skills/more-loop-verify/SKILL.md $(SKILLS_DIR)/more-loop-verify/SKILL.md
	mkdir -p $(DATA_DIR)/system-prompts
	cp $(REPO_DIR)system-prompts/*.md $(DATA_DIR)/system-prompts/
	@echo "  Installed system prompts to $(DATA_DIR)/system-prompts/"
	@if [ -f $(REPO_DIR)server.py ]; then \
		cp $(REPO_DIR)server.py $(DATA_DIR)/server.py; \
		echo "  Installed $(DATA_DIR)/server.py"; \
	fi
	@if [ -f $(REPO_DIR)dashboard.html ]; then \
		cp $(REPO_DIR)dashboard.html $(DATA_DIR)/dashboard.html; \
		echo "  Installed $(DATA_DIR)/dashboard.html"; \
	fi
	@echo "Installed more-loop to $(BIN_DIR)/"

uninstall: ## Remove installed binary and skills
	rm -f $(BIN_DIR)/more-loop
	rm -rf $(SKILLS_DIR)/more-loop-prompt
	rm -rf $(SKILLS_DIR)/more-loop-verify
	rm -rf $(DATA_DIR)
	@echo "Uninstalled more-loop"

link: ## Symlink binary and skills (for development)
	mkdir -p $(BIN_DIR)
	ln -sf $(REPO_DIR)more-loop $(BIN_DIR)/more-loop
	mkdir -p $(SKILLS_DIR)/more-loop-prompt $(SKILLS_DIR)/more-loop-verify
	ln -sf $(REPO_DIR).claude/skills/more-loop-prompt/SKILL.md $(SKILLS_DIR)/more-loop-prompt/SKILL.md
	ln -sf $(REPO_DIR).claude/skills/more-loop-verify/SKILL.md $(SKILLS_DIR)/more-loop-verify/SKILL.md
	mkdir -p $(DATA_DIR)/system-prompts
	@for f in $(REPO_DIR)system-prompts/*.md; do \
		ln -sf "$$f" $(DATA_DIR)/system-prompts/$$(basename "$$f"); \
	done
	@echo "  Linked system prompts to $(DATA_DIR)/system-prompts/"
	@if [ -f $(REPO_DIR)server.py ]; then \
		ln -sf $(REPO_DIR)server.py $(DATA_DIR)/server.py; \
		echo "  Linked $(DATA_DIR)/server.py"; \
	fi
	@if [ -f $(REPO_DIR)dashboard.html ]; then \
		ln -sf $(REPO_DIR)dashboard.html $(DATA_DIR)/dashboard.html; \
		echo "  Linked $(DATA_DIR)/dashboard.html"; \
	fi
	@echo "Linked more-loop to $(BIN_DIR)/ (edits in repo are reflected immediately)"

unlink: ## Remove symlinks
	rm -f $(BIN_DIR)/more-loop
	rm -rf $(SKILLS_DIR)/more-loop-prompt
	rm -rf $(SKILLS_DIR)/more-loop-verify
	@echo "Unlinked more-loop"
