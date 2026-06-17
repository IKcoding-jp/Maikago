'use strict';

// Cloud Functions の memberIds 再計算ロジック（純粋関数）の単体テスト。
// Node 20+ 内蔵テストランナー（node --test）で実行。追加依存なし。
const { test } = require('node:test');
const assert = require('node:assert/strict');

const { computeMemberIds, memberIdsEqual } = require('../familyMemberIds');

test('computeMemberIds: 正常な members から id 配列を返す', () => {
  assert.deepEqual(
    computeMemberIds([
      { id: 'a', name: 'A' },
      { id: 'b', name: 'B' },
    ]),
    ['a', 'b']
  );
});

test('computeMemberIds: null要素・id欠如要素を除外する（壊れた1件で全体を巻き込まない）', () => {
  assert.deepEqual(
    computeMemberIds([{ id: 'a' }, null, { name: 'noid' }, { id: 'c' }]),
    ['a', 'c']
  );
});

test('computeMemberIds: 空配列は空配列', () => {
  assert.deepEqual(computeMemberIds([]), []);
});

test('computeMemberIds: 配列でなければ空配列（undefined/null/map形式に防御的）', () => {
  assert.deepEqual(computeMemberIds(undefined), []);
  assert.deepEqual(computeMemberIds(null), []);
  assert.deepEqual(computeMemberIds({ a: {}, b: {} }), []);
});

test('memberIdsEqual: 順序が違っても同一集合なら true（ループ防止用）', () => {
  assert.equal(memberIdsEqual(['a', 'b', 'c'], ['c', 'a', 'b']), true);
});

test('memberIdsEqual: 要素が違えば false', () => {
  assert.equal(memberIdsEqual(['a', 'b'], ['a', 'c']), false);
});

test('memberIdsEqual: 長さが違えば false', () => {
  assert.equal(memberIdsEqual(['a'], ['a', 'b']), false);
});

test('memberIdsEqual: 非配列にも防御的', () => {
  assert.equal(memberIdsEqual(null, []), true);
  assert.equal(memberIdsEqual(undefined, ['a']), false);
});
