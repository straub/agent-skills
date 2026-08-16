# Anti-Patterns & Gotchas

## Table of Contents
- [CPS Gotchas](#cps-gotchas)
- [Serialization Issues](#serialization-issues)
- [Common Code Smells](#common-code-smells)
- [Library Design Anti-patterns](#library-design-anti-patterns)
- [Real-World Mistakes](#real-world-mistakes)

## CPS Gotchas

Jenkins Pipeline uses **Continuation Passing Style (CPS)** for durability (surviving restarts). This transforms Groovy code in ways that break some patterns.

### Gotcha 1: Closures with side effects

```groovy
// ❌ WRONG: May fail due to CPS transformation
def list = [1, 2, 3]
def doubled = list.collect { it * 2 }
echo doubled  // Might not work!

// ✅ CORRECT: Use script block
script {
    def list = [1, 2, 3]
    def doubled = list.collect { it * 2 }
    echo doubled
}

// ✅ ALSO CORRECT: Use explicit loop
def list = [1, 2, 3]
def doubled = []
for (item in list) {
    doubled.add(item * 2)
}
echo doubled
```

**Why:** CPS transforms closures in ways that can break variable capture and mutation tracking.

### Gotcha 2: Complex conditionals in when blocks

```groovy
// ❌ RISKY: Complex expression may not evaluate correctly
when {
    expression { 
        def branches = env.BRANCH_NAME.split('/')
        branches.size() == 2 && branches[0] == 'release'
    }
}

// ✅ BETTER: Move to script block
when {
    expression { isReleaseBranch() }
}

// Then define as script
def isReleaseBranch() {
    def branches = env.BRANCH_NAME.split('/')
    return branches.size() == 2 && branches[0] == 'release'
}
```

### Gotcha 3: Calling non-step methods directly

```groovy
// ❌ WRONG: Helper methods called at top level may not work
def helper = new MyHelper()
helper.doSomething()  // Might fail during CPS transformation

// ✅ CORRECT: Call from script block
script {
    def helper = new MyHelper()
    helper.doSomething()
}

// ✅ ALSO CORRECT: Call pipeline steps properly
node {
    def helper = new MyHelper(this)  // Pass 'this'
    helper.doSomething()
}
```

### Gotcha 4: Return statements in closures

```groovy
// ❌ WRONG: Return in closure doesn't return from enclosing method
def process(List items) {
    items.each {
        if (it < 0) return  // Skips to next item, doesn't exit function!
    }
}

// ✅ CORRECT: Use findAll or explicit looping
def process(List items) {
    items.findAll { it >= 0 }.each {
        // Process positive items
    }
}

// ✅ ALSO CORRECT: Explicit loop with break
def process(List items) {
    for (item in items) {
        if (item < 0) break
        // Process item
    }
}
```

### Gotcha 5: Reference to 'this' in closures

```groovy
// ❌ RISKY: 'this' may not refer to what you expect
def runner = new PipelineRunner()
[1, 2, 3].each {
    runner.execute()  // 'this' context might be wrong
}

// ✅ BETTER: Capture reference explicitly
def runner = new PipelineRunner()
def capturedRunner = runner
[1, 2, 3].each {
    capturedRunner.execute()
}

// ✅ ALSO CORRECT: Use closure parameter
def runner = new PipelineRunner()
[1, 2, 3].each { item ->
    runner.execute(item)  // Explicit parameter, not implicit 'this'
}
```

## Serialization Issues

Jenkins suspends pipelines and resumes them later. Objects must be serializable.

### Issue 1: Non-serializable fields

```groovy
// ❌ WRONG: Non-serializable objects stored
class BuildContext implements Serializable {
    def steps        // OK: steps is serializable
    def config       // OK: Map is serializable
    def file = new File('/tmp/test')  // ❌ File is NOT serializable
}

// ✅ CORRECT: Only store serializable data
class BuildContext implements Serializable {
    private static final long serialVersionUID = 1L
    def steps
    String filePath  // Store path, not File
    
    File getFile() {
        new File(filePath)  // Reconstruct when needed
    }
}
```

### Issue 2: Transient state on global variables

```groovy
// ❌ WRONG: Global state lost after Jenkins restart
// vars/build.groovy
def buildCount = 0  // Lost if Jenkins restarts!

def call() {
    buildCount++
    echo "Build number: ${buildCount}"
}

// ✅ CORRECT: Use local variable or environment
// vars/build.groovy
def call() {
    def buildNum = env.BUILD_NUMBER
    echo "Build number: ${buildNum}"
}
```

### Issue 3: Third-party non-serializable libraries

```groovy
// ❌ WRONG: Storing non-serializable HTTP client
class HttpHelper implements Serializable {
    def httpClient = new HttpClient()  // NOT serializable
}

// ✅ CORRECT: Create fresh instance when needed
class HttpHelper implements Serializable {
    private static final long serialVersionUID = 1L
    
    def makeRequest(String url) {
        def client = new HttpClient()
        try {
            return client.get(url)
        } finally {
            client.close()
        }
    }
}

// ✅ ALSO CORRECT: Use static methods that don't need state
class HttpHelper {
    static def makeRequest(String url) {
        def client = new HttpClient()
        try {
            return client.get(url)
        } finally {
            client.close()
        }
    }
}
```

### Issue 4: ClassNotFoundException after library update

```groovy
// PROBLEM: Changed class name without migration
// OLD: org.example.BuildConfig
// NEW: org.example.PipelineConfig

// OLD serialized objects try to deserialize as old class → failure

// SOLUTION: Ensure serialVersionUID and backwards compatibility
class PipelineConfig implements Serializable {
    private static final long serialVersionUID = 1L  // Increment on breaking changes
    
    String version
    // ...
}
```

## Common Code Smells

### Smell 1: Monolithic pipeline files

```groovy
// ❌ BAD: 1000+ line pipeline doing everything
vars/megaPipeline.groovy (1000 lines)
├── Build Docker image
├── Run tests
├── Deploy to staging
├── Run integration tests
├── Deploy to production
├── Create GitHub release
├── Notify Slack
└── ... 50 more tasks

// ✅ GOOD: Separate concerns
vars/dockerBuild.groovy
vars/runTests.groovy
vars/deploy.groovy
vars/notify.groovy

// Then compose in Jenkinsfile
@Library('my-lib') _
pipeline {
    stages {
        stage('Build') { steps { dockerBuild() } }
        stage('Test') { steps { runTests() } }
        stage('Deploy') { steps { deploy('prod') } }
        stage('Notify') { steps { notify('success') } }
    }
}
```

### Smell 2: Global variable pollution

```groovy
// ❌ BAD: Global state scattered everywhere
// vars/config.groovy
def awsRegion = 'us-east-1'
def dockerRegistry = 'gcr.io/my-project'
def slackChannel = '#deployments'
// ... 30 more globals

// ✅ GOOD: Single config source
// resources/config.json
{
  "aws": { "region": "us-east-1" },
  "docker": { "registry": "gcr.io/my-project" },
  "slack": { "channel": "#deployments" }
}

// vars/config.groovy
def call() {
    return readJSON(text: libraryResource('config.json'))
}
```

### Smell 3: Disabled linting rules (technical debt)

```groovy
// ❌ BAD: Suppressing linting issues
@SuppressWarnings(['CatchException', 'MethodSize'])  // Hiding problems!
def call() {
    // 500+ lines of complex code
    try {
        // catch-all exception handling
    } catch (Exception e) {
        // Loses original error context
    }
}

// ✅ GOOD: Fix root causes
def call() {
    // 100-line method with single responsibility
    try {
        // Handle specific exceptions
    } catch (IOException e) {
        error "Network error: ${e.message}"
    } catch (ParseException e) {
        error "Invalid config: ${e.message}"
    }
}
```

### Smell 4: Verbose debugging output

```groovy
// ❌ BAD: Debug output clutters logs
pipeline {
    stages {
        stage('Build') {
            steps {
                sh 'set -x; mvn clean package'  // Trace ALL commands
                sh 'env | sort'                 // Print all 100+ environment vars
                sh 'printenv | grep HOME'       // Redundant after above
            }
        }
    }
}

// ✅ GOOD: Conditional debug output
pipeline {
    stages {
        stage('Build') {
            steps {
                script {
                    if (env.DEBUG == 'true') {
                        sh 'set -x; mvn clean package'
                    } else {
                        sh 'mvn clean package'
                    }
                }
            }
        }
    }
}
```

## Library Design Anti-patterns

### Anti-pattern 1: God objects

```groovy
// ❌ BAD: One class does everything
// src/org/example/Pipeline.groovy
class Pipeline implements Serializable {
    def build() { /* ... */ }
    def test() { /* ... */ }
    def deploy() { /* ... */ }
    def notify() { /* ... */ }
    def rollback() { /* ... */ }
    // 500+ lines
}

// ✅ GOOD: Separate concerns
// src/org/example/Builder.groovy
class Builder implements Serializable { def build() { } }

// src/org/example/Tester.groovy
class Tester implements Serializable { def test() { } }

// src/org/example/Deployer.groovy
class Deployer implements Serializable { def deploy() { } }
```

### Anti-pattern 2: Library expects specific Jenkins plugins

```groovy
// ❌ BAD: Fails silently if plugin not installed
// vars/deploy.groovy
def call(String env) {
    // Assumes 'deployer' plugin exists
    deployer.deploy(env)  // MethodMissingException if plugin missing!
}

// ✅ GOOD: Check and document dependencies
// vars/deploy.groovy
def call(String env) {
    if (!pluginManager.plugins.find { it.id == 'deployer-plugin' }) {
        error '''
            Missing required plugin: deployer-plugin
            Install via: Manage Jenkins → Manage Plugins
        '''
    }
    deployer.deploy(env)
}

// Document in SKILL.md
// "Requires: deployer-plugin, git-plugin"
```

### Anti-pattern 3: Hardcoded repository assumptions

```groovy
// ❌ BAD: Assumes all repos follow same structure
// vars/test.groovy
def call() {
    sh 'mvn test'  // Fails for Gradle projects!
}

// ✅ GOOD: Auto-detect or ask for config
// vars/test.groovy
def call(Map config = [:]) {
    if (!config.buildTool) {
        // Auto-detect
        if (fileExists('pom.xml')) {
            config.buildTool = 'maven'
        } else if (fileExists('build.gradle')) {
            config.buildTool = 'gradle'
        } else {
            error 'Unknown build tool (set buildTool: "maven" or "gradle")'
        }
    }
    
    switch (config.buildTool) {
        case 'maven':
            sh 'mvn test'
            break
        case 'gradle':
            sh 'gradle test'
            break
    }
}

// Usage
test(buildTool: 'gradle')
```

## Real-World Mistakes

### Mistake 1: Credentials in SCM

```groovy
// ❌ WRONG: API key in Jenkinsfile
pipeline {
    environment {
        API_KEY = 'sk-1234567890abcdef'
    }
    stages {
        stage('Deploy') {
            steps {
                sh 'curl -H "Authorization: Bearer ${API_KEY}" https://api.example.com'
            }
        }
    }
}

// ✅ CORRECT: Use Jenkins credentials
pipeline {
    environment {
        API_KEY = credentials('api-key-credential')
    }
    stages {
        stage('Deploy') {
            steps {
                sh 'curl -H "Authorization: Bearer ${API_KEY}" https://api.example.com'
            }
        }
    }
}
```

### Mistake 2: SCM operations in shallow clones

```groovy
// ❌ PROBLEM: Shallow clone breaks git history operations
options {
    skipDefaultCheckout()
}

stages {
    stage('Checkout') {
        steps {
            checkout([$class: 'GitSCM',
                      branches: [[name: '*/master']],
                      depth: 1])  // Shallow clone!
            
            sh 'git log --oneline | head -10'  // Fails!
        }
    }
}

// ✅ CORRECT: Full clone when needed
stages {
    stage('Checkout') {
        steps {
            checkout([$class: 'GitSCM',
                      branches: [[name: '*/master']]])  // Full clone
            
            sh 'git log --oneline | head -10'  // Works
        }
    }
}
```

### Mistake 3: Ignoring pipeline resource limits

```groovy
// ❌ BAD: Unbounded parallelism
pipeline {
    stages {
        stage('Massive Parallel') {
            parallel {
                stage('Test 1') { steps { sh 'sleep 600' } }
                stage('Test 2') { steps { sh 'sleep 600' } }
                // ... 1000 more stages
            }
        }
    }
}

// ✅ GOOD: Limit parallelism
pipeline {
    options {
        disableConcurrentBuilds()  // Only one build at a time
        timestamps()
        timeout(time: 1, unit: 'HOURS')
    }
    
    stages {
        stage('Tests') {
            parallel(failFast: false) {
                stage('Unit Tests') { steps { sh 'mvn test' } }
                stage('Integration') { steps { sh 'mvn verify' } }
                stage('Lint') { steps { sh 'eslint .' } }
            }
        }
    }
}
```

### Mistake 4: Not cleaning up workspace/artifacts

```groovy
// ❌ BAD: Disk fills up over time
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'make build'
                archiveArtifacts artifacts: '**/*.jar'
            }
        }
    }
}

// ✅ GOOD: Explicit cleanup policy
pipeline {
    agent any
    
    options {
        // Keep only recent builds
        buildDiscarder(logRotator(numToKeepStr: '20', artifactNumToKeepStr: '5'))
        cleanWs()  // Clean workspace before each build
    }
    
    stages {
        stage('Build') {
            steps {
                sh 'make build'
                archiveArtifacts artifacts: '**/*.jar'
            }
        }
    }
    
    post {
        always {
            // Explicit cleanup
            cleanWs(deleteDirs: true, patterns: [
                [pattern: '**/*.tmp', type: 'INCLUDE'],
                [pattern: 'node_modules', type: 'INCLUDE']
            ])
        }
    }
}
```

---

**Key Takeaway:** Most anti-patterns come from either misunderstanding CPS/serialization or copying patterns from one context without adapting them. Understand the **why**, not just the **what**.
