import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const { adaptiveDepth } = JSON.parse(readFileSync(new URL('../routing/workflow-selection.json', import.meta.url), 'utf8'));

test('standard places design between reconnaissance and planning', () => {
  assert.deepEqual(adaptiveDepth.standard, [
    'intake',
    'dynamic-reconnaissance',
    'design',
    'planning',
    'task-graph',
    'implementation',
    'review',
    'final-verification',
  ]);
});

test('high risk places design after audit and before independent plans', () => {
  assert.deepEqual(adaptiveDepth['high-risk'], [
    'intake',
    'parallel-reconnaissance',
    'audit',
    'design',
    'independent-plans',
    'adjudication',
    'task-graph',
    'implementation',
    'review-loops',
    'final-verification',
  ]);
});

test('light retains its original chain without design', () => {
  assert.deepEqual(adaptiveDepth.light, [
    'intake',
    'implementation',
    'independent-review',
    'final-verification',
  ]);
  assert.equal(adaptiveDepth.light.includes('design'), false);
});

test('no depth retains the architecture stage token', () => {
  for (const [depth, stages] of Object.entries(adaptiveDepth)) {
    assert.equal(stages.includes('architecture'), false, `${depth} retains architecture`);
  }
});
