all:

test:
	grok-commit -A 
	git push 
	scripts/pull-test.sh
