---
name: jenkins-groovy-pipelines
description: Design, implement, and maintain Jenkins Declarative/Scripted Pipelines and Shared Libraries. Use when building Jenkinsfiles, creating shared library components (vars/ custom steps, src/ classes), optimizing pipeline performance, debugging pipeline failures, or refactoring Jenkins pipeline code. Covers both Declarative and Scripted syntax, Groovy patterns for Jenkins, CPS (Continuous Pipeline Steps) gotchas, shared library architecture, testing strategies, and proven patterns from production systems.
---

# Jenkins Groovy Pipelines Skill

Master designing and building Jenkins pipelines and shared libraries with proven patterns, best practices, and real-world lessons learned.

## Quick Navigation

- **[Creating Shared Libraries](references/shared-libraries.md)** - Structure, vars/, src/, testing approaches
- **[Best Practices](references/best-practices.md)** - Performance, maintainability, security patterns
- **[Anti-Patterns & Gotchas](references/anti-patterns.md)** - Common mistakes, CPS issues, serialization problems
- **[Orchestration Patterns](references/orchestration-patterns.md)** - Complex workflows, parallel execution, retry strategies

## Core Concepts

### Declarative vs Scripted Pipeline

**Declarative Pipeline** - Recommended for most use cases:
- Cleaner syntax, easier to read
- Built-in features: post conditions, options, parameters, triggers, environment
- Sandbox by default (safer for untrusted code)
- Use when: Standard CI/CD workflows with clear stages

```groovy
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }
    }
}
```

**Scripted Pipeline** - For advanced/dynamic workflows:
- Full Groovy expressiveness
- Better for complex conditional logic
- Requires `node` blocks for workspace allocation
- Use when: Highly dynamic pipelines or legacy migration

```groovy
node {
    stage('Build') {
        if (env.BRANCH_NAME == 'master') {
            sh 'mvn clean package -P prod'
        }
    }
}
```

### Shared Libraries: High-Level Strategy

Shared libraries solve the "keep pipelines DRY" problem. Three layers:

1. **`vars/` directory** - Global custom steps (stateless functions in `.groovy` files)
   - Expose functionality like `myCustomStep()` or `myCustomStep { ... }`
   - Simple functions, no classes needed
   - Best for: Custom DSLs, common workflows, build wrappers

2. **`src/` directory** - Reusable Groovy classes (standard package structure)
   - Import and use like regular Java classes
   - Must implement `Serializable` to preserve state across suspension points
   - Best for: Complex utilities, object-oriented logic, step wrappers

3. **`resources/` directory** - Static data files
   - Load with `libraryResource('path/to/file')`
   - Immutable configuration, JSON schemas, templates
   - Best for: Configuration, documentation, templates

## Workflow: Building a New Shared Library Component

### 1. Identify what to extract

- **Repeating logic** across multiple pipelines
- **Complex utilities** that don't fit in a single file
- **Configuration** that changes per-project but follows a pattern

Example: If five pipelines all do "retry on transient failures + log recovery", extract into `vars/resilientStep.groovy`.

### 2. Choose the right location

| Use Case | Location | Type |
|----------|----------|------|
| Custom step (e.g., `doSomething()`) | `vars/doSomething.groovy` | Stateless function |
| Complex utility class | `src/org/myorg/Utilities.groovy` | Serializable class |
| Immutable config | `resources/config.json` | Static file |
| Step wrapper with options | `vars/myStep.groovy` with Map config | Function + options |

### 3. Design for serialization

Jenkins pipelines suspend/resume; your state must survive:

```groovy
package org.myorg

class BuildHelper implements Serializable {
    private static final long serialVersionUID = 1L
    def steps  // passed from pipeline (Serializable)
    
    BuildHelper(steps) {
        this.steps = steps
    }
    
    void build(String target) {
        steps.sh "make ${target}"
    }
}
```

### 4. Access pipeline steps

Only pipeline steps (not arbitrary code) can call Jenkins steps like `sh`, `git`, `echo`. Pass the step context explicitly:

```groovy
// vars/myStep.groovy - CORRECT: receives 'this' (pipeline context)
def call(Closure body) {
    node('linux') {
        body()  // steps available in closure
    }
}

// src/org/myorg/Helper.groovy - WRONG: no access to 'sh'
class Helper {
    def doWork() {
        sh 'echo test'  // ❌ ERROR: sh not available
    }
}

// src/org/myorg/Helper.groovy - CORRECT: steps passed in
class Helper implements Serializable {
    def steps
    Helper(steps) { this.steps = steps }
    
    def doWork() {
        steps.sh 'echo test'  // ✅ CORRECT
    }
}
```

## Common Patterns

### Pattern 1: Custom Step with Options (vars/)

```groovy
// vars/gradleBuild.groovy
def call(Map config = [:]) {
    def defaults = [
        tasks: 'build',
        javaVersion: '11',
        parallel: false
    ]
    config = defaults + config
    
    withEnv(["JAVA_HOME=/usr/lib/jvm/java-${config.javaVersion}"]) {
        sh "gradle ${config.tasks}${config.parallel ? ' --parallel' : ''}"
    }
}
```

Usage:
```groovy
@Library('my-shared-lib') _
gradleBuild tasks: 'test', javaVersion: '17'
```

### Pattern 2: Error Handling & Retry Logic

```groovy
// vars/resilientStep.groovy
def call(Map config = [:], Closure body) {
    int maxRetries = config.maxRetries ?: 3
    int retryDelay = config.retryDelay ?: 5  // seconds
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
            body()
            return
        } catch (Exception e) {
            if (attempt == maxRetries) throw e
            
            echo "⚠️  Attempt ${attempt} failed: ${e.message}"
            echo "🔄 Retrying in ${retryDelay}s..."
            sleep(time: retryDelay, unit: 'SECONDS')
        }
    }
}
```

Usage:
```groovy
resilientStep(maxRetries: 5, retryDelay: 10) {
    sh 'flaky-network-command'
}
```

### Pattern 3: Conditional Stages by Branch/Environment

```groovy
pipeline {
    agent any
    
    stages {
        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }
        
        stage('Security Scan') {
            when {
                branch 'main'
            }
            steps {
                sh 'sonarqube-scan'
            }
        }
        
        stage('Deploy') {
            when {
                allOf {
                    branch 'main'
                    expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                }
            }
            steps {
                sh 'deploy.sh'
            }
        }
    }
}
```

### Pattern 4: Parallel Execution for Speed

```groovy
pipeline {
    agent any
    
    stages {
        stage('Test') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        sh 'mvn test'
                    }
                }
                stage('Integration Tests') {
                    agent { label 'docker' }
                    steps {
                        sh 'mvn verify -P integration'
                    }
                }
                stage('Lint') {
                    steps {
                        sh 'eslint .'
                    }
                }
            }
        }
    }
}
```

**Performance gain:** 3 sequential stages take ~60s; parallel reduces to ~20s (limited by longest stage).

### Pattern 5: Using Global Variables Safely

```groovy
// vars/config.groovy - Load immutable config
@groovy.transform.Field
private static final CONFIG = [
    artifactBucket: 'builds-prod',
    notificationEmail: 'team@example.com'
]

def getArtifactBucket() {
    CONFIG.artifactBucket
}
```

❌ **Don't do this:**
```groovy
// vars/config.groovy - WRONG: stateful global variable
def currentBuild = [:]  // Lost on Jenkins restart!

def setBuildInfo(info) {
    currentBuild = info
}
```

✅ **Do this instead:**
```groovy
// Pipeline code
@Library('my-lib') _
def buildInfo = [status: 'started', time: System.currentTimeMillis()]
// Use local variable, not global
```

## Workflow: Debugging Pipeline Failures

### 1. Check execution context

```groovy
pipeline {
    agent any
    options {
        timestamps()  // Adds timestamps to all output
        timeout(time: 1, unit: 'HOURS')  // Prevent hanging
    }
    stages {
        stage('Debug') {
            steps {
                // Print environment
                sh 'env | sort'
                
                // Print Jenkins variables
                echo "Branch: ${env.BRANCH_NAME}"
                echo "Workspace: ${env.WORKSPACE}"
                echo "Build: ${currentBuild.number}"
            }
        }
    }
}
```

### 2. Use sh with verbose flags

```groovy
// Shell scripts
sh 'set -x; your-command'  // Trace all commands

// Maven
sh 'mvn -X clean package'  // Debug mode

// Gradle
sh 'gradle --debug build'
```

### 3. Capture and inspect artifacts

```groovy
pipeline {
    post {
        always {
            // Save logs/artifacts even on failure
            archiveArtifacts artifacts: '**/target/**/*.log', 
                             allowEmptyArchive: true
            
            junit testResults: '**/target/test-results/**/*.xml',
                  allowEmptyResults: true
        }
    }
}
```

### 4. Check shared library loading

```groovy
@Library('my-shared-lib') _

pipeline {
    agent any
    stages {
        stage('Verify Library') {
            steps {
                // Ensure your custom step exists
                script {
                    try {
                        // Call a dummy method to verify library loaded
                        myCustomStep()
                    } catch (Exception e) {
                        error "Library not loaded: ${e.message}"
                    }
                }
            }
        }
    }
}
```

## Key Gotchas

### Gotcha 1: CPS Transformation Issues

Jenkins uses Continuation Passing Style (CPS) for durability. Some Groovy features don't work:

```groovy
// ❌ WRONG: Closures in non-step context
def list = [1,2,3]
def doubled = list.collect { it * 2 }  // May fail!

// ✅ CORRECT: Use explicit loops or script block
script {
    def list = [1,2,3]
    def doubled = list.collect { it * 2 }  // Safe inside script
}
```

See [Anti-Patterns Guide](references/anti-patterns.md#cps-gotchas) for detailed CPS issues.

### Gotcha 2: Serialization Breaks State

```groovy
// ❌ WRONG: Non-serializable class stored in global
class NonSerializable {
    def config = System.properties  // Not serializable!
}

// ✅ CORRECT: Make serializable or pass as parameter
class SerializableHelper implements Serializable {
    String configPath
    
    def loadConfig() {
        return readJSON(file: configPath)
    }
}
```

### Gotcha 3: Credentials in Logs

```groovy
// ❌ WRONG: Credentials logged
withCredentials([usernamePassword(credentialsId: 'myCredId', 
                                   usernameVariable: 'USER', 
                                   passwordVariable: 'PASS')]) {
    sh "echo $PASS"  // Password in logs!
}

// ✅ CORRECT: Use masking or don't echo secrets
withCredentials([usernamePassword(credentialsId: 'myCredId', 
                                   usernameVariable: 'USER', 
                                   passwordVariable: 'PASS')]) {
    sh 'curl -u $USER:$PASS https://api.example.com'  // Jenkins masks $PASS
}
```

## Further Learning

- **Complex orchestration** (parallel stages with dependencies, dynamic parallelization): See [Orchestration Patterns](references/orchestration-patterns.md)
- **Testing shared libraries** (unit tests, mocking Jenkins API): See [Best Practices](references/best-practices.md#testing)
- **Performance optimization** (caching, parallel execution, node affinity): See [Best Practices](references/best-practices.md#performance)
- **Common mistakes to avoid**: See [Anti-Patterns & Gotchas](references/anti-patterns.md)

## Official References

- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [Shared Libraries Guide](https://www.jenkins.io/doc/book/pipeline/shared-libraries/)
- [Pipeline Syntax Reference](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [CPS Method Mismatches](https://www.jenkins.io/doc/book/pipeline/cps-method-mismatches/)
