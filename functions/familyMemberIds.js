'use strict';

// ファミリーの非正規化フィールド memberIds（UID文字列の配列）を members から計算する純粋関数群。
// Firestore ルールの人数無制限メンバー判定（isFamilyMember）と、書き込み側の堅牢化（Issue #198）で使う。
// 副作用なし＝node --test で単体テスト可能。index.js から require する。

// members 配列（[{id, name}, ...]）から memberIds（UID文字列の配列）を計算する。
// - 配列でなければ [] を返す（undefined・null・map形式に防御的）
// - null 要素・id 欠如の要素は除外（壊れた1件で全体を巻き込まない）
// - 重複排除はしない（valid な members とサイズ整合を保ち、ルールの memberIdsConsistent と一致させる）
function computeMemberIds(members) {
  if (!Array.isArray(members)) return [];
  return members.filter((m) => m && m.id).map((m) => m.id);
}

// 2つの memberIds 配列が（順序無視で）同一かを判定する。
// onDocumentUpdated トリガのループ防止に使う（変化が無ければ書き戻さない）。
function memberIdsEqual(a, b) {
  const x = Array.isArray(a) ? a : [];
  const y = Array.isArray(b) ? b : [];
  if (x.length !== y.length) return false;
  const sx = [...x].sort();
  const sy = [...y].sort();
  return sx.every((v, i) => v === sy[i]);
}

module.exports = { computeMemberIds, memberIdsEqual };
