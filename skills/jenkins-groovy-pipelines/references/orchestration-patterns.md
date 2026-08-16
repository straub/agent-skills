# Orchestration Patterns

## Table of Contents
- [Parallel Execution](#parallel-execution)
- [Complex Dependencies](#complex-dependencies)
- [Dynamic Stages](#dynamic-stages)
- [Conditional Workflows](#conditional-workflows)
- [Retry & Recovery Patterns](#retry--recovery-patterns)
- [Production Examples](#production-examples)

## Parallel Execution

### Basic parallel stages

```groovy
pipeline {
    agent any
    
    stages {
        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }
        
        stage('Parallel Tests') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        sh 'mvn test'
                    }
                }
                
                stage('Integration Tests') {
                    agent { label 'docker' }  // Different agent
                    steps {
                        sh 'mvn verify -P integration'
                    }
                }
                
                stage('Security Scan') {
                    steps {
                        sh 'sonarqube-scan'
                    }
                }
            }
        }
    }
}
```

**Performance:** If stages take 10s, 15s, 20s respectively, parallel = 20s vs 45s sequential. Real-world impact: 3-5x faster for complex pipelines.

### Nested parallelism (matrix builds)

Test across multiple platforms simultaneously:

```groovy
pipeline {
    agent any
    
    stages {
        stage('Build Matrix') {
            parallel {
                stage('Linux - Java 11') {
                    agent { label 'linux && java11' }
                    steps {
                        sh 'java -version && mvn clean package'
                    }
                }
                
                stage('Linux - Java 17') {
                    agent { label 'linux && java17' }
                    steps {
                        sh 'java -version && mvn clean package'
                    }
                }
                
                stage('Windows - Java 11') {
                    agent { label 'windows && java11' }
                    steps {
                        bat 'java -version && mvn clean package'
                    }
                }
                
                stage('Windows - Java 17') {
                    agent { label 'windows && java17' }
                    steps {
                        bat 'java -version && mvn clean package'
                    }
                }
                
                stage('macOS - Java 11') {
                    agent { label 'macos && java11' }
                    steps {
                        sh 'java -version && mvn clean package'
                    }
                }
            }
        }
    }
}
```

### Dynamic parallelism (Scripted Pipeline)

Parallelize unknown number of stages:

```groovy
node {
    def versions = ['3.8', '3.9', '3.10', '3.11']
    def parallelStages = [:]
    
    versions.each { version ->
        parallelStages["Python ${version}"] = {
            stage("Python ${version}") {
                sh "python${version} -m pytest tests/"
            }
        }
    }
    
    parallel(parallelStages)
}
```

**Use case:** Build against all supported Python versions without hardcoding stage count.

### Fail-fast vs fail-safe

```groovy
// ✅ FAIL-FAST: Stop on first failure
stage('Tests') {
    parallel(failFast: true) {  // Any failure stops others
        stage('Unit') { steps { sh 'test-unit' } }
        stage('Integration') { steps { sh 'test-integration' } }
        stage('E2E') { steps { sh 'test-e2e' } }
    }
}

// ✅ FAIL-SAFE: Run all, collect results
stage('Tests') {
    parallel(failFast: false) {  // All stages run regardless
        stage('Unit') { steps { sh 'test-unit' } }
        stage('Integration') { steps { sh 'test-integration' } }
        stage('E2E') { steps { sh 'test-e2e' } }
    }
}
```

**Decision:** Use `failFast: true` for CI/CD (stop on first issue), `failFast: false` for dashboards/reports (collect full picture).

## Complex Dependencies

### Stage dependencies: "Deploy only after all tests pass"

```groovy
pipeline {
    agent any
    
    stages {
        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }
        
        stage('Test') {
            parallel {
                stage('Unit') { steps { sh 'mvn test' } }
                stage('Integration') { steps { sh 'mvn verify' } }
                stage('Security') { steps { sh 'sonar-scanner' } }
            }
        }
        
        // Implicitly depends on previous stages
        stage('Deploy') {
            when {
                allOf {
                    branch 'main'
                    expression { currentBuild.result == 'SUCCESS' }
                }
            }
            steps {
                sh 'deploy.sh'
            }
        }
    }
}
```

### Manual dependency via gates

```groovy
pipeline {
    agent any
    
    stages {
        stage('Build') {
            steps {
                sh 'build.sh'
            }
        }
        
        stage('Test') {
            parallel {
                stage('Unit') { steps { sh 'test-unit.sh' } }
                stage('Integration') { steps { sh 'test-integration.sh' } }
            }
        }
        
        stage('Quality Gate') {
            input {
                message 'Quality checks passed. Proceed with deployment?'
                ok 'Deploy'
                submitter 'admin,devops'
            }
        }
        
        stage('Deploy Staging') {
            steps {
                sh 'deploy staging'
            }
        }
        
        stage('Smoke Tests') {
            steps {
                sh 'smoke-tests staging'
            }
        }
        
        stage('Approve Prod') {
            input {
                message 'Ready for production?'
                ok 'Deploy to Prod'
                submitter 'admin'
            }
        }
        
        stage('Deploy Production') {
            steps {
                sh 'deploy production'
            }
        }
    }
}
```

### Complex DAG (Directed Acyclic Graph)

```groovy
// Declarative Pipeline limitations: stages are sequential or parallel only
// For complex DAGs, use Scripted Pipeline

node {
    try {
        // Layer 1: Independent builds
        def buildTasks = [
            'Build App': { sh 'build-app.sh' },
            'Build Docs': { sh 'build-docs.sh' },
            'Build Containers': { sh 'build-containers.sh' }
        ]
        parallel(buildTasks)
        
        // Layer 2: Tests that depend on builds
        def testTasks = [
            'Unit Tests': { sh 'unit-tests.sh' },
            'Integration': { sh 'integration-tests.sh' },
            'Security': { sh 'security-scan.sh' }
        ]
        parallel(testTasks)
        
        // Layer 3: Deployment
        stage('Deploy') {
            sh 'deploy.sh'
        }
        
    } catch (Exception e) {
        echo "Pipeline failed: ${e.message}"
        throw e
    }
}
```

## Dynamic Stages

### Generate stages from configuration

```groovy
// Jenkinsfile
@Library('my-lib') _
pipeline {
    agent any
    
    stages {
        stage('Generate') {
            steps {
                script {
                    // Load config with test environments
                    def config = readJSON(file: 'test-config.json')
                    env.TEST_ENVS = config.environments.join(',')
                }
            }
        }
    }
}

// Scripted equivalent (more flexible)
node {
    def config = readJSON(file: 'test-config.json')
    
    def testStages = [:]
    config.environments.each { env ->
        testStages["Test on ${env}"] = {
            sh "run-tests ${env}"
        }
    }
    
    parallel(testStages)
}
```

Configuration:
```json
// test-config.json
{
  "environments": ["dev", "staging", "prod"],
  "platforms": ["ubuntu", "centos", "alpine"]
}
```

### Generate stages from file system

```groovy
node {
    // Find all test subdirectories, create stage for each
    def testDirs = sh(
        script: 'find tests -type d -maxdepth 1 | sort',
        returnStdout: true
    ).trim().split('\n')
    
    def parallelStages = [:]
    testDirs.each { dir ->
        if (dir.startsWith('tests/')) {
            def name = dir.replace('tests/', '')
            parallelStages["Test: ${name}"] = {
                stage("Test: ${name}") {
                    sh "pytest ${dir}"
                }
            }
        }
    }
    
    parallel(parallelStages)
}
```

## Conditional Workflows

### Branch-specific pipelines

```groovy
pipeline {
    agent any
    
    stages {
        stage('Build') {
            steps {
                sh 'build.sh'
            }
        }
        
        stage('Test') {
            when {
                branch '*/PR-*'  // Only on PRs
            }
            steps {
                sh 'comprehensive-tests.sh'
            }
        }
        
        stage('Deploy Staging') {
            when {
                branch 'develop'
            }
            steps {
                sh 'deploy staging'
            }
        }
        
        stage('Deploy Production') {
            when {
                branch 'main'
            }
            input {
                message 'Deploy to production?'
                ok 'Deploy'
            }
            steps {
                sh 'deploy production'
            }
        }
    }
}
```

### Environment-specific configurations

```groovy
pipeline {
    agent any
    
    stages {
        stage('Configure') {
            steps {
                script {
                    if (env.BRANCH_NAME == 'main') {
                        env.DEPLOY_ENV = 'production'
                        env.NOTIFICATION_EMAIL = 'oncall@example.com'
                        env.REQUIRE_APPROVAL = 'true'
                    } else if (env.BRANCH_NAME.startsWith('release/')) {
                        env.DEPLOY_ENV = 'staging'
                        env.NOTIFICATION_EMAIL = 'team@example.com'
                        env.REQUIRE_APPROVAL = 'false'
                    } else {
                        env.DEPLOY_ENV = 'dev'
                        env.NOTIFICATION_EMAIL = 'dev-team@example.com'
                        env.REQUIRE_APPROVAL = 'false'
                    }
                }
            }
        }
        
        stage('Deploy') {
            steps {
                sh "deploy.sh ${env.DEPLOY_ENV}"
            }
        }
        
        stage('Notify') {
            steps {
                mail to: env.NOTIFICATION_EMAIL,
                     subject: "Deployment to ${env.DEPLOY_ENV}",
                     body: "Build ${env.BUILD_NUMBER} deployed"
            }
        }
    }
}
```

### Multi-condition gates

```groovy
pipeline {
    agent any
    
    stages {
        stage('Build') {
            steps {
                sh 'build.sh'
            }
        }
        
        stage('Deploy to Staging') {
            when {
                allOf {
                    branch 'main'
                    expression { currentBuild.result == 'SUCCESS' }
                }
            }
            steps {
                sh 'deploy staging'
            }
        }
        
        stage('Approval') {
            when {
                anyOf {
                    branch 'main'
                    tag 'v*'
                }
            }
            input {
                message 'Approve production deployment?'
                ok 'Approve'
                submitter 'admin,devops'
            }
        }
        
        stage('Deploy to Production') {
            when {
                expression { currentBuild.result == 'SUCCESS' }
            }
            steps {
                sh 'deploy production'
            }
        }
    }
}
```

## Retry & Recovery Patterns

### Simple retry with backoff

```groovy
// vars/retryWithBackoff.groovy
def call(Map config = [:], Closure body) {
    int maxRetries = config.maxRetries ?: 3
    int baseDelay = config.baseDelay ?: 5  // seconds
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
            body()
            echo "✅ Success on attempt ${attempt}"
            return
        } catch (Exception e) {
            if (attempt == maxRetries) {
                echo "❌ All ${maxRetries} attempts failed"
                throw e
            }
            
            def delay = baseDelay * Math.pow(2, attempt - 1)
            echo "⚠️  Attempt ${attempt} failed: ${e.message}"
            echo "⏳ Retrying in ${delay}s (exponential backoff)..."
            sleep(time: (long)delay, unit: 'SECONDS')
        }
    }
}
```

Usage:
```groovy
retryWithBackoff(maxRetries: 5, baseDelay: 10) {
    sh 'flaky-deployment-command'
}
```

### Intelligent retry (transient error detection)

From production systems (roc jenkins-shared-library):

```groovy
// vars/resilientCommand.groovy
def call(Map config = [:], String command) {
    int maxRetries = config.maxRetries ?: 3
    List transientErrors = config.transientErrors ?: [
        'Connection timeout',
        'Temporary failure in name resolution',
        'Service Unavailable',
        'Bad Gateway',
        'ECONNRESET'
    ]
    
    for (int i = 1; i <= maxRetries; i++) {
        try {
            sh command
            return
        } catch (Exception e) {
            def errorMsg = e.message ?: e.toString()
            def isTransient = transientErrors.any { errorMsg.contains(it) }
            
            if (isTransient && i < maxRetries) {
                def delay = Math.pow(2, i - 1)
                echo "⚠️  Transient error (attempt ${i}/${maxRetries})"
                echo "📊 Error: ${errorMsg}"
                echo "⏳ Retrying in ${delay}s..."
                sleep(time: (long)delay, unit: 'SECONDS')
                continue
            }
            
            throw e
        }
    }
}
```

Usage:
```groovy
resilientCommand(maxRetries: 4, transientErrors: [
    'Connection timeout',
    'Network unreachable'
]) {
    sh '''
        curl -H "Authorization: Bearer ${API_KEY}" \\
             https://api.example.com/deploy
    '''
}
```

### Canary deployment with automatic rollback

```groovy
pipeline {
    agent any
    
    stages {
        stage('Build') {
            steps {
                sh 'build.sh'
            }
        }
        
        stage('Deploy Canary') {
            steps {
                sh 'deploy canary'  // 5% traffic
            }
        }
        
        stage('Monitor Canary') {
            steps {
                script {
                    def health = sh(
                        script: 'check-health.sh canary',
                        returnStdout: true
                    ).trim()
                    
                    if (health != 'HEALTHY') {
                        sh 'rollback canary'
                        error 'Canary deployment failed health checks'
                    }
                }
            }
        }
        
        stage('Deploy Full') {
            steps {
                sh 'deploy full'  // 100% traffic
            }
        }
        
        stage('Verify') {
            steps {
                script {
                    def health = sh(
                        script: 'check-health.sh prod',
                        returnStdout: true
                    ).trim()
                    
                    if (health != 'HEALTHY') {
                        sh 'rollback'
                        error 'Production deployment failed'
                    }
                }
            }
        }
    }
    
    post {
        failure {
            sh 'notify-on-call.sh "Deployment failed, automatic rollback executed"'
        }
    }
}
```

## Production Examples

### Example 1: Mobile app release pipeline

```groovy
pipeline {
    agent any
    
    parameters {
        choice(name: 'RELEASE_TYPE', choices: ['patch', 'minor', 'major'])
    }
    
    stages {
        stage('Build') {
            parallel {
                stage('iOS') {
                    agent { label 'macos' }
                    steps {
                        sh 'xcodebuild -workspace App.xcworkspace -scheme App'
                    }
                }
                stage('Android') {
                    agent { label 'android' }
                    steps {
                        sh 'gradle build'
                    }
                }
            }
        }
        
        stage('Test') {
            parallel {
                stage('iOS Tests') {
                    agent { label 'macos' }
                    steps {
                        sh 'xcodebuild test'
                    }
                }
                stage('Android Tests') {
                    agent { label 'android' }
                    steps {
                        sh 'gradle test'
                    }
                }
            }
        }
        
        stage('Version Bump') {
            steps {
                script {
                    def version = sh(
                        script: 'bump-version.sh ${RELEASE_TYPE}',
                        returnStdout: true
                    ).trim()
                    env.VERSION = version
                }
            }
        }
        
        stage('Build Release') {
            parallel {
                stage('iOS Release') {
                    agent { label 'macos' }
                    steps {
                        sh '''
                            xcodebuild -workspace App.xcworkspace \\
                                      -scheme App \\
                                      -configuration Release \\
                                      -archivePath build/App.xcarchive archive
                        '''
                    }
                }
                stage('Android Release') {
                    agent { label 'android' }
                    steps {
                        sh 'gradle bundleRelease'
                    }
                }
            }
        }
        
        stage('Upload to Stores') {
            parallel {
                stage('iOS to App Store') {
                    steps {
                        sh 'upload-to-appstore.sh build/App.xcarchive'
                    }
                }
                stage('Android to Play Store') {
                    steps {
                        sh 'upload-to-playstore.sh build/app.aab'
                    }
                }
            }
        }
    }
    
    post {
        success {
            sh '''
                git tag v${VERSION}
                git push origin v${VERSION}
                notify-release.sh "Version ${VERSION} released"
            '''
        }
        failure {
            sh 'notify-oncall.sh "Release pipeline failed"'
        }
    }
}
```

### Example 2: Data processing pipeline with quality gates

```groovy
pipeline {
    agent any
    
    stages {
        stage('Extract') {
            parallel {
                stage('Extract from API') {
                    steps {
                        sh 'python3 extract_api.py > data/api.csv'
                    }
                }
                stage('Extract from Database') {
                    steps {
                        sh 'python3 extract_db.py > data/db.csv'
                    }
                }
                stage('Extract from Files') {
                    steps {
                        sh 'python3 extract_files.py > data/files.csv'
                    }
                }
            }
        }
        
        stage('Quality Gate: Data Validation') {
            steps {
                script {
                    def validationResult = sh(
                        script: 'python3 validate_data.py',
                        returnStatus: true
                    )
                    
                    if (validationResult != 0) {
                        error 'Data validation failed'
                    }
                }
            }
        }
        
        stage('Transform') {
            parallel {
                stage('Clean') {
                    steps {
                        sh 'python3 clean_data.py'
                    }
                }
                stage('Normalize') {
                    steps {
                        sh 'python3 normalize_data.py'
                    }
                }
                stage('Enrich') {
                    steps {
                        sh 'python3 enrich_data.py'
                    }
                }
            }
        }
        
        stage('Quality Gate: Transformed Data') {
            steps {
                script {
                    def result = sh(
                        script: 'python3 validate_transform.py',
                        returnStatus: true
                    )
                    
                    if (result != 0) {
                        error 'Transformation validation failed'
                    }
                }
            }
        }
        
        stage('Load') {
            steps {
                sh 'python3 load_warehouse.py'
            }
        }
        
        stage('Report') {
            steps {
                sh 'python3 generate_report.py'
                archiveArtifacts artifacts: 'reports/**'
            }
        }
    }
}
```

---

**Key Takeaway:** Orchestration patterns enable sophisticated workflows that adapt to real-world complexity. Master parallel execution, dependencies, and recovery to build resilient pipelines.
