# Shared Libraries Deep Dive

## Table of Contents
- [Directory Structure](#directory-structure)
- [vars/ Global Variables](#vars-global-variables)
- [src/ Classes](#src-classes)
- [resources/ Static Files](#resources-static-files)
- [Library Configuration](#library-configuration)
- [Testing Strategies](#testing-strategies)
- [Real-World Architecture Patterns](#real-world-architecture-patterns)

## Directory Structure

Official layout from Jenkins documentation:

```
(root)
+- src                           # Groovy source files (imported as classes)
|   +- org
|       +- example
|           +- MyUtility.groovy  # package org.example
+- vars                          # Global variables (custom steps)
|   +- myStep.groovy             # Available as myStep(...)
|   +- myStep.txt                # Help text for myStep
+- resources                     # Static files (external libraries only)
|   +- org
|       +- example
|           +- config.json       # Load via libraryResource(...)
```

### Key principles

1. **Classpath structure in `src/`**: Mirrors Java package structure. `src/org/example/Utils.groovy` → package `org.example`
2. **vars/ naming**: Lowercase with camelCase: `myVar.groovy`, not `MyVar.groovy`
3. **Help text**: `vars/myStep.txt` auto-generates Global Variable Reference (after first successful run)
4. **resources/ only in external libraries**: Internal/folder-level libraries can't use resources/

## vars/ Global Variables

Global variables are **stateless singletons** exposed as custom pipeline steps. Each `.groovy` file becomes one variable.

### Simple custom step (no parameters)

```groovy
// vars/simpleEcho.groovy
def call() {
    echo 'Hello from shared library!'
}
```

Usage:
```groovy
@Library('my-lib') _
simpleEcho()
```

### Custom step with parameters

```groovy
// vars/greet.groovy
def call(String name) {
    echo "Hello, ${name}!"
}
```

Usage:
```groovy
greet 'Alice'
greet('Bob')
```

### Custom step with Map config (recommended)

Map syntax allows named parameters and optional arguments:

```groovy
// vars/deploy.groovy
def call(Map config = [:]) {
    def defaults = [
        environment: 'staging',
        timeout: 30,
        rollback: true
    ]
    
    config = defaults + config  // Merge with overrides
    
    echo "Deploying to ${config.environment}..."
    // ... deployment logic
}
```

Usage:
```groovy
@Library('my-lib') _

// Using defaults
deploy()

// Override specific values
deploy environment: 'prod', timeout: 60

// Multiple overrides
deploy([
    environment: 'prod',
    timeout: 60,
    rollback: false
])
```

### Custom step with closure (block support)

Allows step to accept a block of pipeline code:

```groovy
// vars/onLinux.groovy
def call(Closure body) {
    node('linux') {
        body()
    }
}

// vars/withinDocker.groovy
def call(String image, Closure body) {
    docker.image(image).inside {
        body()
    }
}
```

Usage:
```groovy
onLinux {
    sh 'uname -a'
}

withinDocker('python:3.9') {
    sh 'python --version'
}
```

### Combining parameters and closure

```groovy
// vars/withRetry.groovy
def call(Map config = [:], Closure body) {
    int maxRetries = config.maxRetries ?: 3
    int delay = config.delay ?: 5
    
    for (int i = 1; i <= maxRetries; i++) {
        try {
            body()
            return
        } catch (Exception e) {
            if (i == maxRetries) throw e
            echo "Attempt ${i} failed, retrying in ${delay}s..."
            sleep(time: delay, unit: 'SECONDS')
        }
    }
}
```

Usage:
```groovy
withRetry(maxRetries: 5, delay: 10) {
    sh 'flaky-command'
}
```

### Multiple functions in one file

`.groovy` files in `vars/` become a singleton object. Define multiple methods:

```groovy
// vars/logging.groovy
def info(message) {
    echo "[INFO] ${message}"
}

def warn(message) {
    echo "[WARN] ${message}"
}

def error(message) {
    echo "[ERROR] ${message}"
}
```

Usage:
```groovy
@Library('my-lib') _

logging.info 'Starting build'
logging.warn 'Deprecated feature'
logging.error 'Build failed'
```

### Help text for Global Variables Reference

Create a `.txt` file (Markdown or HTML allowed):

```text
// vars/greet.txt
Greets a person by name.

Usage:
    greet('Alice')
    greet name: 'Bob'

Parameters:
- name (String): The person's name

Example:
    @Library('my-lib') _
    greet 'Alice'
```

Help appears in Jenkins UI under **Pipeline Syntax** → **Global Variable Reference** (after first successful run using the library).

## src/ Classes

Groovy classes for reusable logic. Useful for complex utilities, validation, orchestration.

### Basic class structure

```groovy
// src/org/example/BuildHelper.groovy
package org.example

class BuildHelper implements Serializable {
    private static final long serialVersionUID = 1L
    
    def steps  // Receive pipeline context (this)
    
    BuildHelper(steps) {
        this.steps = steps
    }
    
    void build(String target) {
        steps.echo "Building ${target}..."
        steps.sh "make ${target}"
    }
}
```

Usage from pipeline:

```groovy
@Library('my-lib')
import org.example.BuildHelper

pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                script {
                    def helper = new BuildHelper(this)
                    helper.build('app')
                }
            }
        }
    }
}
```

### Important: Serializable interface

Jenkins pipelines suspend and resume. Objects must survive serialization:

```groovy
// ✅ CORRECT
class Helper implements Serializable {
    private static final long serialVersionUID = 1L
    def steps  // 'this' is serializable
    String configPath
}

// ❌ WRONG: Non-serializable field
class Helper {
    def systemProps = System.properties  // NOT serializable!
}
```

### Static methods vs instance methods

Static methods don't need pipeline context:

```groovy
// src/org/example/Utils.groovy
package org.example

class Utils {
    static String getVersionFromFile(String filePath) {
        // Pure Groovy, no pipeline steps needed
        new File(filePath).text.trim()
    }
}
```

Usage:

```groovy
@Library('my-lib')
import static org.example.Utils.getVersionFromFile

pipeline {
    agent any
    stages {
        stage('Read') {
            steps {
                script {
                    def version = getVersionFromFile('VERSION.txt')
                    echo "Version: ${version}"
                }
            }
        }
    }
}
```

### Passing steps to static methods

To use pipeline steps in static methods, pass `this`:

```groovy
// src/org/example/Utils.groovy
package org.example

class Utils {
    static void printEnv(script) {
        script.sh 'printenv | sort'
    }
}
```

Usage:

```groovy
@Library('my-lib')
import static org.example.Utils.printEnv

pipeline {
    agent any
    stages {
        stage('Debug') {
            steps {
                script {
                    printEnv(this)
                }
            }
        }
    }
}
```

## resources/ Static Files

Load immutable configuration and templates (external libraries only).

### Loading resources

Use `libraryResource` step:

```groovy
// resources/org/example/docker-compose.yml
version: '3'
services:
  app:
    image: myapp:latest
```

From pipeline:

```groovy
def composefile = libraryResource('org/example/docker-compose.yml')
writeFile(file: 'docker-compose.yml', text: composefile)
sh 'docker-compose up'
```

### Common use cases

1. **JSON configuration**
   ```groovy
   // resources/config.json
   {
     "buckets": ["staging", "prod"],
     "timeout": 3600
   }
   
   // Pipeline
   def config = readJSON(text: libraryResource('config.json'))
   ```

2. **Shell scripts**
   ```groovy
   // resources/scripts/deploy.sh
   #!/bin/bash
   set -e
   echo "Deploying..."
   # ... logic
   
   // Pipeline
   writeFile(file: 'deploy.sh', text: libraryResource('scripts/deploy.sh'))
   sh 'chmod +x deploy.sh && ./deploy.sh'
   ```

3. **Templates**
   ```groovy
   // resources/templates/email.html
   <h1>Build ${buildNumber}</h1>
   <p>Status: ${buildStatus}</p>
   
   // Pipeline
   def template = libraryResource('templates/email.html')
   def body = template.replace('${buildStatus}', 'SUCCESS')
   ```

## Library Configuration

### Defining shared libraries in Jenkins

Navigate: **Manage Jenkins** → **System** → **Global Trusted Pipeline Libraries**

Configuration options:

1. **Name**: Identifier for `@Library('name')`
2. **Default version**: Branch/tag used if not specified (e.g., `main`)
3. **Modern SCM**: Git, GitHub, etc. (recommended)
4. **Allow default version override**: Allow Jenkinsfile to use `@Library('name@branch')`
5. **Load implicitly**: Auto-load for all pipelines (convenient but affects security)

### Dynamic library loading

Load libraries at runtime without pre-configuration:

```groovy
@Library('my-lib@master') _
library('my-lib@develop')  // Load specific version dynamically

pipeline {
    stages {
        stage('Test') {
            steps {
                script {
                    def dynamicLib = library('utils@${env.BRANCH_NAME}')
                    // Access from loaded library...
                }
            }
        }
    }
}
```

### Versioning strategies

- **Branch-based**: `@Library('my-lib@main')` - Always latest main
- **Tag-based**: `@Library('my-lib@1.2.3')` - Stable version
- **Commit-based**: `@Library('my-lib@abc123')` - Exact version
- **Branch expression**: `@Library("my-lib@${env.BRANCH_NAME}")` - Mirror branch

## Testing Strategies

### Integration testing (real pipelines)

Use a dedicated **test pipeline** repository:

```groovy
// Jenkinsfile in test repo
@Library('my-lib@master') _

pipeline {
    agent any
    stages {
        stage('Test Custom Step') {
            steps {
                myCustomStep()  // Verify it works
            }
        }
    }
}
```

Triggers: Run on shared library changes (via webhooks or periodic).

### Unit testing (Groovy mocking)

For library classes, write unit tests with mock Jenkins context:

```groovy
// test/org/example/BuildHelperTest.groovy
import org.junit.Test
import static org.mockito.Mockito.*

class BuildHelperTest {
    @Test
    void testBuild() {
        def mockSteps = mock(Object)
        def helper = new org.example.BuildHelper(mockSteps)
        
        helper.build('app')
        
        verify(mockSteps).sh('make app')
    }
}
```

Run with: `mvn test` or `gradle test`

### Testing library via Pull Request

Test a library PR before merging:

```groovy
// Consumer Jenkinsfile
@Library('my-lib@pull/42/head') _  // GitHub PR branch syntax

pipeline {
    // Your pipeline...
}
```

## Real-World Architecture Patterns

### Pattern 1: Layered architecture

Separate concerns: DSL → utilities → steps

```
vars/
├── pipeline.groovy           # High-level DSL
├── deploy.groovy             # Deployment step
└── logging.groovy            # Logging utilities

src/
├── org/example/Config.groovy       # Load config
├── org/example/Docker.groovy       # Docker utilities
└── org/example/Credentials.groovy  # Secret management
```

### Pattern 2: Immutable configuration with resources/

```
resources/
├── config/
│   ├── prod.json
│   ├── staging.json
│   └── dev.json

vars/
└── deploy.groovy  # Loads appropriate config by environment
```

### Pattern 3: Branch-aware library version selection

Different library versions per branch:

```groovy
// Jenkinsfile
@Library("my-lib@${env.BRANCH_NAME == 'main' ? 'stable' : 'dev'}") _

pipeline {
    // Main branch uses 'stable' tag, others use 'dev'
}
```

### Pattern 4: Composable steps (decorator pattern)

Stack behaviors:

```groovy
// vars/withMetrics.groovy
def call(Closure body) {
    timestamps()
    ansiColor('xterm') {
        body()
    }
}

// Usage
withMetrics {
    sh 'your-command'
}
```

---

**Key Takeaway:** Shared libraries should be **stateless, reusable, and serializable**. Treat them like you'd treat a well-designed library in any language: clear interfaces, minimal coupling, comprehensive testing.
