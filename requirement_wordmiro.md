# 1. 目的／背景

IELTS Reading 7.5–8.0 レベルの語彙を対象に、1語を起点として関連語（類義・反義・派生・コロケーション等）を樹状に可視化し、**日本語約400字の要点解説**とともに段階的に「広げて学ぶ」体験を提供する。手書きメモリーツリーの効果（関連付け・精緻化）を、LLMとiOS/iPadOSのインタラクティブUIで再現・拡張する。

# 2. スコープ（MVP）

- **対象OS**：iOS/iPadOS 17以降（Apple Silicon Macの最小対応は任意）。
- **主要機能**：
  - 単語入力 → LLM応答（400字解説＋関連語JSON） → キャンバスへノード/エッジ追加。
  - ノードタップで解説カード（日本語約400字＋例文EN/JA）表示。
  - 子ノードの「展開」操作で同フローを再帰的に実行（重複統合）。
  - キャンバスのズーム/パン、ノードドラッグ、ワンクリック自動整列（力学レイアウト）。
  - 簡易学習モード（当該サブグラフの1問1答＋3段階評価）。
  - ローカル保存（SwiftData）／JSONエクスポート・インポート。
- **非スコープ（後送）**：リアルタイム共同編集、手書き/フリーノート、画像添付、サーバーサイドユーザー管理、辞書APIの商用連携、Web版。

# 3. 前提・制約

- **HIG準拠**：iPad最適化（大画面レイアウト、ポインタ、キーボードショートカット、Split View/Stage Manager）、タップターゲット、モーション控えめ、Undo/Redo、シンプルな色数・階層強調。ダークモード対応。
- **語彙レンジ**：IELTS Reading 7.5–8.0相当のやや硬め英単語を主対象。解説は日本語で約400字、専門用語は過度に噛み砕かない。
- **LLM**：外部API想定。BFF（Backend For Frontend）を介して叩く。出力は**厳格JSON**のみ。
- **プライバシー**：個人情報不要。送信は検索語のみ。テレメトリは匿名集計。
- **辞書ライセンス**：MVPはLLM生成＋ユーザー入力のみ（外部辞書本文の複製は禁止）。

# 4. 主要ユーザーストーリー

- **US-01**：学習者として、単語を入力すると、400字解説と関連語ネットワークが表示され、未知語を辿って拡張できるようにしたい。
- **US-02**：学習者として、任意のノード群をクイズ化し、「覚えた/要復習/忘れた」を記録したい。
- **US-03**：学習者として、作成したネットワークをJSONで外部保存/共有したい。

# 5. 画面/UX要件（HIG準拠）

## 5.1 画面一覧

- **ボード画面（メイン）**：
  - 上部：検索バー（単語入力、Returnで送信）。
  - 中央：キャンバス（ピンチズーム、2指パン、ノードドラッグ）。
  - 右下FAB：①＋（新規ノード） ②⚙（自動整列） ③▶（学習モード）。
- **解説カード（下部半モーダル）**：見出し語／品詞／register（文体）／約400字解説／例文EN/JA／「展開」ボタン。
- **学習モード**：選択サブグラフを1問1答化。回答後に3ボタン（覚えた／要復習／忘れた）。

## 5.2 インタラクション

- ノード：タップ＝選択、ダブルタップ＝フォーカス＆カード表示、ドラッグ＝位置変更。
- エッジ：タップで関係タイプ表示（同義/反義/派生/連想/コロケーション）。
- 配色：タイプ別（例：同義=Blue、反義=Red、派生=Teal、連想=Gray、コロケーション=Indigo）。色弱配慮のため**線種やラベル**でも区別。
- iPad：ポインタホバーでラベル表示、Cmd+Fで検索、Cmd+0で全体フィット、Cmd+Lで整列。
- Undo/Redo：ノード追加/削除/移動、レイアウト適用、展開の取り消しに対応。

# 6. 機能要件（抜粋）

- **FR-001 単語追加**：入力→/expand API→中央に親ノード、子ノードは円環配置。既存語は重複作成せずフォーカス移動。
- **FR-002 解説表示**：ノードカードに約400字の日本語解説、例文EN/JA、register（文体）を表示。コピー可能。
- **FR-003 展開**：未展開ノードで「展開」を押すとAPI呼出→子ノード生成。展開済みフラグでループ抑止。
- **FR-004 自動整列**：ワンクリックでFR（Fruchterman–Reingold）風レイアウトを100–300イテレーションで計算し適用。
- **FR-005 学習モード**：選択ノード群を出題。3段階評価でSRSを更新。
- **FR-006 保存/入出力**：SwiftDataに自動保存。エクスポート/インポートはJSON（下記スキーマ）。
- **FR-007 検索/ジャンプ**：検索バーに既存語を入れると該当ノードへズーム。

# 7. 非機能要件

- **NFR-001 レスポンス**：/expand のP95 < 2.5s（キャッシュヒット時 < 400ms）。
- **NFR-002 フレームレート**：表示ノード200・エッジ300で60fps（最悪30fps維持）。
- **NFR-003 安定性**：連続展開100回でクラッシュ0。メモリ上限目安 < 350MB。
- **NFR-004 オフライン**：ネット不可時は既存ノード閲覧のみ可。展開は不可。
- **NFR-005 セキュリティ**：APIキーは端末に保持せずBFFで管理。通信はTLS1.2+。

# 8. データモデル（アプリ内）

```json
// Export JSON v1
{
  "version": 1,
  "nodes": [
    {
      "id": "UUID",
      "lemma": "ubiquitous",
      "pos": "adjective",
      "register": "ややフォーマル",
      "explanation_ja": "約400字…",
      "example_en": "Smartphones are ubiquitous in modern society.",
      "example_ja": "現代社会ではスマートフォンは至る所に存在する。",
      "x": 120.5,
      "y": -42.0,
      "expanded": true,
      "ease": 2.3,
      "next_review_at": "2025-08-20T00:00:00Z"
    }
  ],
  "edges": [
    { "id": "UUID", "from": "UUID", "to": "UUID", "type": "synonym" }
  ]
}
```

- **RelationType**：`synonym | antonym | associate | etymology | collocation`。
- **正規化**：lemmaは小文字化、ハイフン・空白は単一スペース。既存lemma一致で重複禁止。

# 9. LLM/BFF 仕様

## 9.1 API（BFF）

- `POST /expand`\
  **Request**：`{ "lemma": "ubiquitous", "locale": "ja", "max_related": 12 }`\
  **Response**（LLM正規化後に返却）：
  ```json
  {
    "lemma": "ubiquitous",
    "pos": "adjective",
    "register": "ややフォーマル",
    "explanation_ja": "約400字…",
    "example_en": "…",
    "example_ja": "…",
    "related": [
      {"term":"omnipresent","relation":"synonym"},
      {"term":"pervasive","relation":"associate"},
      {"term":"scarce","relation":"antonym"},
      {"term":"ubiquity","relation":"etymology"},
      {"term":"ubiquitous computing","relation":"collocation"}
    ]
  }
  ```
- **バリデーション**：JSON Schema準拠、未充足はHTTP 422。rate limit（例：IP/ユーザー毎 60 req/min）。
- **キャッシュ**：`(lemma, locale)`キー、TTL 7日。`ETag`/`If-None-Match`対応。

## 9.2 プロンプト（LLM）

**System**：

> あなたは英語語彙の解説専門家。IELTS Reading 7.5–8.0レベルを想定し、やや硬めの語彙解説を日本語で約400字で作成。語源/ニュアンス/代表用例（EN→JA訳）を含め、出力は指定JSONのみ。

**User**（例）：

```
語: ubiquitous
言語: ja
関係語タイプ: synonym/antonym/associate/etymology/collocation
各タイプの上限: 3（合計最大12）
出力JSONスキーマ: { lemma,pos,register,explanation_ja,example_en,example_ja,related[] }
約束: JSON以外の出力・箇条書き・改行装飾は禁止。文字数は約400字。
```

**推奨パラメータ**：`temperature 0.2–0.4, top_p 0.9, presence_penalty 0.0`。

# 10. レイアウトアルゴリズム（MVP）

- **方式**：FR（Fruchterman–Reingold）簡易版。反発力=距離逆二乗、引力=フックの法則、冷却スケジュール指数減衰。100–300イテレーション。
- **適用**：ユーザーが⚙実行時のみ（常時シミュレーションはしない）。
- **初期配置**：親の周囲に均等角度で円環配置（半径は子数×ノードサイズに応じて自動）。

# 11. 学習（SRS）

- **評価**：覚えた/要復習/忘れた（3段階）。
- **間隔**：
  - 覚えた：`interval *= 2.5; ease += 0.05`
  - 要復習：`interval *= 1.2`
  - 忘れた：`interval = 1; ease = max(2.0, ease - 0.2)`
- **対象集合**：中心ノード＋距離1–2の近傍。日単位で次回出題。

# 12. エラーハンドリング

- **LLM失敗/422**：カードに簡潔なエラー。再試行ボタン、プロンプト見直し提案（内部）。
- **重複語**：既存ノードにズーム。必要なら「別品詞として追加」選択肢。
- **過密**：ノード>200で新規展開を警告。折りたたみ機能で抑制。

# 13. テレメトリ/設定

- ローカル設定：最大ノード数、レイアウト強度、フォントサイズ（Dynamic Type互換）。
- 匿名イベント：/expand成功率、応答時間、キャンバスノード数分布。個人識別情報は収集しない。

# 14. 品質保証（抜粋）

- **ユニット**：正規化、重複統合、SRS計算、レイアウト1ステップ。
- **スナップショット**：主要画面のライト/ダーク。
- **パフォーマンス**：200ノード・300エッジで60fps、メモリ<350MB、レイアウト処理<500ms（iPad Pro M1相当）。
- **E2E（Gherkin例）**：
  - `Given` 起動直後\
    `When` 検索バーに“ubiquitous”を入力しReturn\
    `Then` 中央に親ノードと最大12の子ノードが円環配置される\
    `And` 親ノードをダブルタップすると約400字の解説カードが表示される。

# 15. 開発体制・技術スタック（推奨）

- **クライアント**：SwiftUI + MVVM、SwiftData、Combine。外部ライブラリ最小。
- **BFF**：FastAPI or Cloud Functions（TypeScript/Nodeでも可）。JSON Schemaで検証、キャッシュ（Redis/Cloudflare）。
- **CI**：Xcode Cloud or GitHub Actions（ユニット/スナップショット/リンタ）。

# 16. セキュリティ/法務

- APIキーはサーバー保管。アプリには埋め込まない。
- 著作権配慮：外部辞書の原文転載なし。LLM生成物の帰属・利用許諾は利用規約で明示。

# 17. 受け入れ基準（MVP完了）

1. US-01/02/03のE2Eテストが全て合格。
2. NFR-001〜005を満たす測定結果が揃う。
3. クラッシュフリーセッション率 > 99.5%。
4. HIGチェックリスト（レイアウト・ジェスチャ・アクセシビリティ最低限・ダークモード）を満たす。

# 18. 付録

## 付録A：SwiftDataモデル（参考）

```swift
enum RelationType: String, Codable, CaseIterable { case synonym, antonym, associate, etymology, collocation }

@Model
final class WordNode { @Attribute(.unique) var id: UUID = .init(); var lemma: String; var pos: String?; var register: String?; var explanationJA: String; var exampleEN: String?; var exampleJA: String?; var x: Double = 0; var y: Double = 0; var expanded: Bool = false; var ease: Double = 2.3; var nextReviewAt: Date?; init(lemma: String, explanationJA: String) { self.lemma = lemma; self.explanationJA = explanationJA } }

@Model
final class WordEdge { @Attribute(.unique) var id: UUID = .init(); var from: UUID; var to: UUID; var type: RelationType; init(from: UUID, to: UUID, type: RelationType) { self.from = from; self.to = to; self.type = type } }
```

## 付録B：JSON Schema（/expand 応答）

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["lemma","explanation_ja","related"],
  "properties": {
    "lemma": {"type":"string"},
    "pos": {"type":["string","null"]},
    "register": {"type":["string","null"]},
    "explanation_ja": {"type":"string","minLength":120},
    "example_en": {"type":["string","null"]},
    "example_ja": {"type":["string","null"]},
    "related": {
      "type":"array","maxItems":12,
      "items": {
        "type":"object",
        "required":["term","relation"],
        "properties":{
          "term":{"type":"string"},
          "relation":{"enum":["synonym","antonym","associate","etymology","collocation"]}
        }
      }
    }
  }
}
```

