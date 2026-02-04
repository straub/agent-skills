---
name: running-tests
description: Use ANYTIME you're running a suite of tests from the command line.
---

# Running Tests

Test suites can sometimes take a very long time to run, consume lots of system
resources, and generate lots of output. To save time and preserve your context,
follow this simple guide.

## Examples

Use when running

- npm test
- node --test ...
- pytest ...
- ./gradlew ...
- and any test runner

## Guidelines

- Always redirect test output to a file!

```bash
npm test 2>&1 > /tmp/test-output.txt
```

- Analyze that file as needed after the run is finished

```bash
tail -n20 /tmp/test-output.txt

wc -l /tmp/test-output.txt

grep 'fail' /tmp/test-output.txt
```
