INVENTORY ?= inventory/hosts.yml
PLAYBOOK  ?= playbooks/site.yml
TAGS      ?= all
VAULT     ?= --ask-vault-pass

.PHONY: deps lint check deploy

deps:
	ansible-galaxy collection install -r requirements.yml

lint:
	ansible-lint playbooks roles

check:
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK) $(VAULT) --check --diff --tags $(TAGS)

deploy:
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK) $(VAULT) --tags $(TAGS)
