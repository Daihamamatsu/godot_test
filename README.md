# MarioLike

Godot 4.7.2 で作成した 2D プラットフォーマです。
プレイヤーを操作して地形を進み、コインを集め、敵を踏みつけながらコースクリアを目指します。

## ビジュアルとサウンド

- プレイヤーの歩行アニメーションは、`assets/player/walk/` にある 14 枚の PNG フレームを使用します。キック攻撃は `assets/player/attack/` の 21 枚の PNG フレームを使用します。
- 敵キャラクターは `assets/enemy/pien/` の `pien.png`、`korae.png`、`panti.png`、`namida.png` を使用します。この敵素材は本Issueで承認した例外として導入しています。
- 遠景の丘、地形、コイン、ゴールなどは `Polygon2D` などを使ってプロシージャルに描画し、中景の森は `assets/background/midground_forest.png` を横方向にタイル配置します。
- 背景はパララックスレイヤーで構成し、空の遠景、中間距離の森、プレイヤーがいる近景の距離感を表現します。
- 効果音は外部音声ファイルを使わず、`autoload/sfx.gd` の `Sfx` オートロードがコードで生成します。
- 外部プラグイン、アセットパック、外部フォントは使用していません。背景、プレイヤー、敵にはローカルのPNGを使用します。
- `assets/`と`assets_backup/`はGit管理対象外です。現在は同一開発環境でのローカル運用を前提とし、PR完了後に`assets_backup/assets/`へ素材をバックアップします。

## 必要環境

- Godot 4.7.2 stable
- Windows 64bit
- レンダリング方式: `mobile`

## 実行方法

Godot エディタで本プロジェクトを開き、メインシーンを実行してください。

- メインシーン: `scenes/main.tscn`
- エディタから実行: `F6` または `F5`

### ヘッドレススモークテスト

Git Bash から次のコマンドを実行します。

```bash
/g/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe \
  --headless --audio-driver Dummy --quit-after 300 res://scenes/main.tscn test
```

テストが成功すると、次の出力と終了コードになります。

```text
TEST SUMMARY: ALL PASS
EXIT_CODE=0
```

## 操作方法

| 操作 | 内容 |
| --- | --- |
| `A` / `←` | 左へ移動 |
| `D` / `→` | 右へ移動 |
| `SPACE` / `↑` / `W` | ジャンプ |
| `J` | キック攻撃 |
- `P` | 判定可視化モードの切り替え |
| `R` | 現在のコースをリスタート |

ゲーム内 UI は現在英語表示です。

- `SCORE`: スコア
- `LIVES`: 残機
- `READY?`: 開始案内
- `COURSE CLEAR!`: コースクリア
- `GAME OVER`: ゲームオーバー

## ゲーム要素

- 左右移動とジャンプ
- ジャンプバッファ、コヨーテタイム、可変ジャンプ高度
- 14 フレームの歩行アニメーション
- 巡回する敵と、壁・崖での方向転換
- Pien敵の正面索敵攻撃（正面180px以内・上下差96px以内）
- Pien敵の攻撃予備10フレーム、panti拡大8フレーム、攻撃判定3フレーム、残心6フレーム
- Pien敵のパンチは向いている方向の前方へ出現し、korae表示は通常表示と同じサイズ
- プレイヤーの攻撃を受けたPien敵はプレイヤーの方向を向く
- Pien敵の表示サイズを存在判定・攻撃判定に合わせた表示
- Pien敵の攻撃後180フレームのクールタイム
- Pien敵のHP0時の半透明表示90フレーム後の消滅
- プレイヤーと敵のHP/AP制ダメージ
- プレイヤーHPバーと敵HPバー
- 敵の踏みつけ(50 AP)とプレイヤーのキック攻撃(25 AP)
- 敵との接触だけではダメージを受けない攻撃判定・くらい判定
- プレイヤーと敵の存在判定・攻撃判定・くらい判定の可視化モード(`P`)
- コイン取得とスコア加算
- 残機、リスポーン、ゲームオーバー
- ゴール到達によるコースクリア
- コード生成による効果音

## ファイル構成

```text
scenes/
  main.tscn
  player.tscn
  enemy.tscn
  coin.tscn

scripts/
  main.gd
  player.gd
  enemy.gd
  coin.gd

autoload/
  sfx.gd

assets/player/walk/
  walk_01.png ～ walk_14.png
assets/player/attack/
  attack_01.png ～ attack_21.png
assets/enemy/pien/
  pien.png / korae.png / panti.png / namida.png
```

`.uid` ファイルは Godot がスクリプトやリソースを識別するためのサイドカーファイルで、Git 管理対象です。

## 開発ワークフロー

1. GitHub Issue を作成し、変更内容と受け入れ基準を記述する
2. 同じ機能のOpen Issue・Open PRがないことを確認する。存在する場合は既存PRへ修正を積む
3. `main` から `issue/N-キーワード` 形式のブランチを作成する
4. 変更を実装する
5. ヘッドレススモークテストを実行する
6. Conventional Commits 形式で、日本語の説明と Issue 番号を含むコミットを作成する
7. `origin/main`との差分、変更ファイル、重複コミットを確認する
8. 本文に `Closes #N` を含む Pull Request を作成する
9. レビュー後に `main` へマージする
10. PR完了後、`assets/`を`assets_backup/assets/`へバックアップする

`main` への直接コミット、force push、無関係な変更の混在は行いません。