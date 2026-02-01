#!/usr/bin/env node
// Build script to generate prompt template files from skill markdown files

const fs = require('fs');
const path = require('path');

const skills = [
  {
    source: 'skills/test-driven-development/SKILL.md',
    target: 'prompts/tdd-prompt.txt',
    description: 'TDD Skill'
  },
  {
    source: 'skills/jira-cli/SKILL.md',
    target: 'prompts/jira-prompt.txt',
    description: 'Jira CLI Skill'
  }
];

console.log('Building prompt templates from skill files...\n');

for (const skill of skills) {
  const sourcePath = path.join(__dirname, '..', skill.source);
  const targetPath = path.join(__dirname, '..', skill.target);
  
  console.log(`Processing ${skill.description}:`);
  console.log(`  Source: ${skill.source}`);
  console.log(`  Target: ${skill.target}`);
  
  if (!fs.existsSync(sourcePath)) {
    console.error(`  ERROR: Source file not found: ${sourcePath}`);
    process.exit(1);
  }
  
  const skillContent = fs.readFileSync(sourcePath, 'utf8');
  
  const promptTemplate = `${skillContent}

---

User task: {{task}}`;
  
  const targetDir = path.dirname(targetPath);
  if (!fs.existsSync(targetDir)) {
    fs.mkdirSync(targetDir, { recursive: true });
  }
  
  fs.writeFileSync(targetPath, promptTemplate, 'utf8');
  console.log(`  Generated successfully\n`);
}

console.log('All prompt templates built successfully!');
