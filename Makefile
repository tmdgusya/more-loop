PREFIX ?= $(HOME)/.local
BIN_DIR = $(PREFIX)/bin
SKILLS_DIR = $(HOME)/.claude/skills
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
	@echo "Installed more-loop to $(BIN_DIR)/"

uninstall: ## Remove installed binary and skills
	rm -f $(BIN_DIR)/more-loop
	rm -rf $(SKILLS_DIR)/more-loop-prompt
	rm -rf $(SKILLS_DIR)/more-loop-verify
	@echo "Uninstalled more-loop"

link: ## Symlink binary and skills (for development)
	mkdir -p $(BIN_DIR)
	ln -sf $(REPO_DIR)more-loop $(BIN_DIR)/more-loop
	mkdir -p $(SKILLS_DIR)/more-loop-prompt $(SKILLS_DIR)/more-loop-verify
	ln -sf $(REPO_DIR).claude/skills/more-loop-prompt/SKILL.md $(SKILLS_DIR)/more-loop-prompt/SKILL.md
	ln -sf $(REPO_DIR).claude/skills/more-loop-verify/SKILL.md $(SKILLS_DIR)/more-loop-verify/SKILL.md
	@echo "Linked more-loop to $(BIN_DIR)/ (edits in repo are reflected immediately)"

unlink: ## Remove symlinks
	rm -f $(BIN_DIR)/more-loop
	rm -rf $(SKILLS_DIR)/more-loop-prompt
	rm -rf $(SKILLS_DIR)/more-loop-verify
	@echo "Unlinked more-loop"
