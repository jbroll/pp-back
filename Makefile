.PHONY: test clean

test:
	@./test-pp-back.sh

clean:
	rm -rf test test.ppb test.ppb.exclude
