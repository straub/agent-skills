# Jenkins Pipeline Best Practices

## Table of Contents
- [Performance Optimization](#performance-optimization)
- [Maintainability](#maintainability)
- [Security](#security)
- [Testing](#testing)
- [Configuration Management](#configuration-management)
- [Observability & Debugging](#observability--debugging)
- [Production-Proven Patterns](#production-proven-patterns)

## Performance Optimization

### Parallel execution (30-50% speed improvement)

Use `parallel` blocks to run independent tasks simultaneously:

```groovy
pipeline {
    agent any
    
    stages {
        stage('Test') {
            parallel {
                stage('Unit Tests') {
                    agent any  // Can use different agent
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
                
                stage('Code Quality') {
                    steps {
                        sh 'sonar-scanner'
                    }
                }
            }
        }
    }
}
```

**Key insight:** Total time = longest stage (not sum). If Unit/Integration/Quality take 10/15/5s respectively, parallel runs in ~15s vs ~30s sequential.

### Caching strategies

Avoid repeated expensive operations:

#### 1. Docker layer caching
```groovy
// Dockerfile
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y maven  # Cached layer
COPY . /app                                      # Invalidates if source changes
WORKDIR /app
RUN mvn clean package                            # Re-runs if source changed
```

#### 2. Maven/Gradle cache
```groovy
pipeline {
    agent any
    
    options {
        // Keep .m2 repository between builds
        preserveStashes(buildCount: 5)
    }
    
    stages {
        stage('Build') {
            steps {
                sh 'mvn -o clean package'  // -o: offline (uses cached dependencies)
            }
        }
    }
}
```

#### 3. Workspace cleanup strategies
```groovy
options {
    // Clean workspace before build (fresh state)
    cleanWs()
    
    // Keep recent builds' workspaces (for quick bisecting)
    buildDiscarder(
        logRotator(
            numToKeepStr: '10',         // Keep 10 builds
            artifactNumToKeepStr: '5'   // Keep 5 with artifacts
        )
    )
}
```

### Agent affinity (reduce context switching)

```groovy
pipeline {
    agent any
    
    stages {
        stage('Build') {
            agent { label 'linux && docker' }
            steps {
                // Runs on specific agent type
                sh 'docker build .'
            }
        }
        
        stage('Test on Windows') {
            agent { label 'windows' }
            steps {
                bat 'gradlew test'
            }
        }
    }
}
```

**Why it matters:** Affinity reduces filesystem thrashing, improves cache hits, and predictably isolates different workload types.

### Timeout and abort stale builds

```groovy
options {
    // Fail if build takes >1 hour
    timeout(time: 1, unit: 'HOURS')
    
    // Abort previous builds of same branch
    disableConcurrentBuilds()
}
```

## Maintainability

### Single Responsibility Principle in shared libraries

Each component should have one reason to change:

```groovy
// ✅ GOOD: Clear separation
vars/
├── dockerBuild.groovy       # Only Docker build logic
├── dockerPush.groovy        # Only Docker push logic
├── sonarQubeScan.groovy     # Only SonarQube integration
└── logging.groovy           # Only logging utilities

src/
├── org/example/DockerUtil.groovy    # Docker helpers
└── org/example/SlackNotifier.groovy # Slack notification

// ❌ BAD: Mixed responsibilities
vars/
└── megaPipeline.groovy  # 1000+ lines doing everything
```

### Declarative vs Scripted: Choose wisely

**Use Declarative when:**
- Standard CI/CD workflows (build, test, deploy)
- Multiple team members (readable syntax)
- Blue Ocean visualization matters
- Sandboxing is important

```groovy
pipeline {
    agent any
    stages {
        stage('Build') { steps { sh 'make' } }
        stage('Test') { steps { sh 'make test' } }
    }
}
```

**Use Scripted when:**
- Complex conditional logic
- Dynamic stage generation
- Legacy pipeline migration
- Need full Groovy flexibility

```groovy
node {
    def images = ['ubuntu', 'centos', 'alpine']
    
    images.each { image ->
        stage("Test on ${image}") {
            // Dynamic stages
        }
    }
}
```

### Configuration as code (immutable defaults)

```groovy
// ✅ GOOD: Explicit, testable defaults
vars/deploy.groovy

def call(Map config = [:]) {
    def defaults = [
        timeout: 300,
        retries: 3,
        environment: 'staging',
        healthCheck: true
    ]
    
    config = defaults + config
    // Defaults always present, overrideable
}

// ❌ BAD: Magic numbers scattered throughout
pipeline {
    stages {
        stage('Deploy') {
            steps {
                sh 'deploy.sh'
                sleep(300)  // What is this 300?
            }
        }
    }
}
```

### Naming conventions

Clear, self-documenting names reduce cognitive load:

```groovy
// ✅ GOOD: Intention is clear
- buildDebugArtifacts
- uploadToStagingBucket
- waitForHealthChecksToPass
- retryWithExponentialBackoff

// ❌ BAD: Ambiguous
- processFiles
- doStuff
- step1, step2, step3
- helpers
```

## Security

### Credentials management

#### Never log credentials

```groovy
// ✅ CORRECT: Jenkins masks credentials
withCredentials([
    usernamePassword(credentialsId: 'github-credentials',
                     usernameVariable: 'GITHUB_USER',
                     passwordVariable: 'GITHUB_TOKEN')
]) {
    sh '''
        curl -u $GITHUB_USER:$GITHUB_TOKEN https://api.github.com
        // Jenkins masks $GITHUB_TOKEN in output
    '''
}

// ❌ WRONG: Avoid explicitly echoing
withCredentials([...]) {
    sh 'echo $GITHUB_TOKEN'  // DON'T DO THIS
}
```

#### Use credential scopes appropriately

```groovy
// For sensitive operations, limit credential scope
withCredentials([file(credentialsId: 'prod-deploy-key', variable: 'DEPLOY_KEY')]) {
    sh 'deploy-prod.sh'  // Credentials only available in this block
}

// Outside block: DEPLOY_KEY not available
sh 'echo $DEPLOY_KEY'  // Empty
```

### Groovy sandboxing

Declarative Pipeline runs in sandbox (safer for untrusted scripts). Scripted Pipeline trusts the author more.

```groovy
// Declarative: Sandboxed
pipeline {
    agent any
    stages {
        stage('Test') {
            steps {
                // Restricted Groovy execution
                script {
                    System.exit(1)  // ❌ Blocked
                }
            }
        }
    }
}

// Scripted: Requires trust
node {
    System.exit(1)  // ✅ Allowed (if job author is trusted)
}
```

### Audit trail for deployments

```groovy
pipeline {
    options {
        // Log who approved deployment
        buildDiscarder(logRotator(numToKeepStr: '100'))
    }
    
    stages {
        stage('Deploy to Production') {
            input {
                message 'Deploy to production?'
                ok 'Deploy'
                submitter 'admin,devops'  // Only admins/devops can approve
            }
            steps {
                // Audit: Jenkins logs who approved
                sh 'deploy-prod.sh'
            }
        }
    }
}
```

## Testing

### Testing shared library classes

```groovy
// src/org/example/ConfigParser.groovy
package org.example

class ConfigParser implements Serializable {
    static def parse(String json) {
        new groovy.json.JsonSlurper().parseText(json)
    }
}

// test/org/example/ConfigParserTest.groovy
import org.junit.Test
import static org.junit.Assert.*

class ConfigParserTest {
    @Test
    void testParseValidJson() {
        def json = '{"env":"prod","timeout":300}'
        def config = org.example.ConfigParser.parse(json)
        
        assertEquals('prod', config.env)
        assertEquals(300, config.timeout)
    }
    
    @Test
    void testParseInvalidJson() {
        assertThrows(Exception) {
            org.example.ConfigParser.parse('invalid')
        }
    }
}
```

Run: `mvn test`

### Testing global variables (integration test)

Create a test pipeline repository:

```groovy
// test-pipelines/Jenkinsfile
@Library('my-shared-lib@master') _

pipeline {
    agent any
    
    stages {
        stage('Verify Deploy Step') {
            steps {
                // Test the custom step
                deploy(environment: 'staging', dryRun: true)
                echo '✅ Deploy step works'
            }
        }
        
        stage('Verify Logging') {
            steps {
                logging.info 'Test message'
                echo '✅ Logging works'
            }
        }
    }
}
```

Trigger on library changes → run test pipeline → success confirms library works.

### Mocking Jenkins steps

```groovy
// test/org/example/DeployHelperTest.groovy
import org.junit.Test
import static org.mockito.Mockito.*

class DeployHelperTest {
    @Test
    void testDeployCallsSh() {
        def mockSteps = mock(Object)
        def helper = new org.example.DeployHelper(mockSteps)
        
        helper.deploy('prod')
        
        verify(mockSteps).sh(contains('deploy-prod.sh'))
        verify(mockSteps).echo(contains('Deploying'))
    }
}
```

## Configuration Management

### Environment variables over hardcoding

```groovy
// ✅ GOOD: Configurable
pipeline {
    environment {
        DOCKER_REGISTRY = 'gcr.io/my-project'
        BUILD_TIMEOUT = '3600'
        SLACK_CHANNEL = '#deployments'
    }
    
    stages {
        stage('Build') {
            steps {
                sh 'docker push ${DOCKER_REGISTRY}/myapp'
            }
        }
    }
}

// ❌ BAD: Hardcoded
sh 'docker push gcr.io/my-project/myapp'
```

### Branch-specific configuration

```groovy
pipeline {
    agent any
    
    stages {
        stage('Configure') {
            steps {
                script {
                    if (env.BRANCH_NAME == 'main') {
                        env.DEPLOY_ENV = 'production'
                        env.REQUIRE_APPROVAL = 'true'
                    } else if (env.BRANCH_NAME.startsWith('release/')) {
                        env.DEPLOY_ENV = 'staging'
                        env.REQUIRE_APPROVAL = 'false'
                    } else {
                        env.DEPLOY_ENV = 'dev'
                        env.REQUIRE_APPROVAL = 'false'
                    }
                }
            }
        }
        
        stage('Deploy') {
            when {
                expression { env.REQUIRE_APPROVAL == 'false' }
            }
            steps {
                sh 'deploy.sh ${DEPLOY_ENV}'
            }
        }
    }
}
```

### Centralized config files (resources/)

```groovy
// resources/deployments/prod.yaml
environment: production
timeout: 3600
notifications:
  slack: '#alerts'
  email: 'oncall@example.com'

// Pipeline
def config = readYaml(file: 'deployments/prod.yaml')
echo "Deploying to ${config.environment}"
```

## Observability & Debugging

### Structured logging

```groovy
// vars/log.groovy
def info(msg) {
    echo "[${env.STAGE_NAME}] [INFO] ${msg}"
}

def debug(msg) {
    if (env.DEBUG == 'true') {
        echo "[${env.STAGE_NAME}] [DEBUG] ${msg}"
    }
}

def error(msg) {
    echo "[${env.STAGE_NAME}] [ERROR] ${msg}"
}

// Usage
@Library('my-lib') _
pipeline {
    stages {
        stage('Build') {
            steps {
                log.info 'Starting build'
                log.debug 'Compiler version: ' + getCompilerVersion()
            }
        }
    }
}
```

### Build badges for quick status

```groovy
post {
    always {
        // Generate badges for GitHub README
        publishHTML([
            allowMissing: false,
            alwaysLinkToLastBuild: true,
            keepAll: true,
            reportDir: 'build/reports',
            reportFiles: 'index.html',
            reportName: 'Test Report'
        ])
    }
    
    success {
        // Update success badge
    }
    
    failure {
        // Update failure badge
    }
}
```

### Artifact preservation for debugging

```groovy
post {
    always {
        // Keep logs/diagnostics even if build fails
        archiveArtifacts artifacts: '**/target/**/*.log', 
                         allowEmptyArchive: true
        
        junit testResults: '**/target/test-results/**/*.xml',
              allowEmptyResults: true
        
        // Custom reports
        publishHTML(target: [
            reportDir: 'build/reports/coverage',
            reportFiles: 'index.html',
            reportName: 'Code Coverage'
        ])
    }
}
```

## Production-Proven Patterns

### Pattern 1: Semantic Versioning + Automated Releases

```groovy
// Jenkinsfile
@Library('my-lib@main') _

pipeline {
    triggers {
        githubPush()
    }
    
    stages {
        stage('Test') {
            steps {
                sh 'mvn test'
            }
        }
        
        stage('Release') {
            when {
                branch 'main'
            }
            steps {
                script {
                    // Determine next version (from commit message)
                    def version = determineVersion()
                    
                    sh "git tag -a v${version} -m 'Release ${version}'"
                    sh "git push origin v${version}"
                    
                    // Publish to artifact repository
                    sh "mvn deploy"
                }
            }
        }
    }
}
```

### Pattern 2: Auto-detect and Recover from Transient Failures

From real production libraries (roc jenkins-shared-library):

```groovy
// vars/resilientCommand.groovy
def call(Map config = [:], String command) {
    def maxRetries = config.maxRetries ?: 3
    def knownTransientErrors = [
        'Connection timeout',
        'Temporary failure in name resolution',
        'Service Unavailable'
    ]
    
    for (int i = 1; i <= maxRetries; i++) {
        try {
            sh command
            return
        } catch (Exception e) {
            def errorMsg = e.message
            
            if (isTransientError(errorMsg, knownTransientErrors)) {
                if (i < maxRetries) {
                    def delay = Math.pow(2, i - 1)  // Exponential backoff
                    echo "⚠️  Transient error (attempt ${i}/${maxRetries})"
                    echo "📊 Backing off for ${delay}s..."
                    sleep(time: (long)delay, unit: 'SECONDS')
                    continue
                }
            }
            
            throw e
        }
    }
}

def isTransientError(String msg, List knownErrors) {
    knownErrors.any { msg?.contains(it) }
}
```

### Pattern 3: Configuration merging with intelligent defaults

From production (eng jenkins-shared-library):

```groovy
// vars/buildPipeline.groovy
def call(Map userConfig = [:]) {
    def defaults = readJSON(text: libraryResource('config/defaults.json'))
    def branchConfig = readJSON(text: libraryResource("config/${env.BRANCH_NAME}.json"))
    
    // Layer: defaults ← branch-specific ← user overrides
    def config = defaults + branchConfig + userConfig
    
    pipeline {
        agent any
        stages {
            stage('Build') {
                steps {
                    sh config.buildCommand
                }
            }
        }
    }
}
```

---

**Key Takeaway:** Production-ready pipelines balance performance, security, and maintainability through thoughtful design and proven patterns.
