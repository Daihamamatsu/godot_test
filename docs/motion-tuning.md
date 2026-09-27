# モーション調整手順

## 概要

プレイヤーと敵のモーション設定は、`data/motions/` の Godot Resource にまとめています。
Godot エディタで `.tres` ファイルを開き、Inspector の値を変更すると、コードを変更せずに表示・再生・攻撃判定を調整できます。

## 対象ファイル

```text
data/motions/
  player_walk.tres    # プレイヤー歩行
  player_attack.tres  # プレイヤーのキック攻撃
  enemy_attack.tres   # Pien敵の攻撃
```

モーション共通の定義は `scripts/motion_data.gd` にあります。
画像ファイル自体は既存のローカル素材を参照しており、新しい画像・音声・フォントを追加する必要はありません。

## 基本手順

1. Godot エディタでプロジェクトを開く。
2. FileSystem ドックで `data/motions/` を開く。
3. 編集する `.tres` を選択する。
4. Inspector で値を変更する。
5. シーンを実行して挙動を確認する。
6. `P` キーで判定可視化を有効にし、攻撃判定が意図した位置・大きさ・タイミングになっているか確認する。
7. 調整後にヘッドレススモークテストを実行する。

## プレイヤー歩行の調整

対象ファイル: `data/motions/player_walk.tres`

| 項目 | 内容 |
| --- | --- |
| `sprite_frames` | `walk` アニメーションの画像フレーム。フレームの追加・削除・差し替えに使用する |
| `fps` | 1 秒あたりの再生フレーム数。大きくすると歩行が速くなる |
| `loop` | 歩行中にアニメーションを繰り返すかどうか |
| `sprite_scale` | 歩行スプライトの表示倍率 |
| `sprite_offset` | プレイヤー原点からの表示位置補正 |
| `idle_frame` | 停止時に表示するフレーム。0 始まり |
| `minimum_move_speed` | この速度を超えたときに歩行アニメーションを再生する |

現在の歩行モーションは 14 フレーム、10 FPS、ループ有効です。
フレーム番号は 0 始まりなので、1 枚目は 0、14 枚目は 13 です。

### 歩行を速くする

`fps` を大きくします。例えば `10.0` から `14.0` にすると、同じ 14 フレームをより短い時間で再生します。
実際のプレイヤー移動速度は `scripts/player.gd` の `MOVE_SPEED` であり、歩行画像の再生速度とは別の設定です。

### 歩行画像の位置や大きさを調整する

`sprite_scale` と `sprite_offset` を変更します。
キャラクターの物理判定は自動では変わらないため、画像だけを大きく変更した場合は、必要に応じて `scenes/player.tscn` の存在判定・くらい判定も確認してください。

## プレイヤー攻撃の調整

対象ファイル: `data/motions/player_attack.tres`

| 項目 | 内容 |
| --- | --- |
| `sprite_frames` | キック攻撃の画像フレーム |
| `fps` | 攻撃アニメーションの再生速度 |
| `damage` | 敵に与える AP ダメージ |
| `active_start_frame` | 攻撃判定を開始するフレーム。0 始まり |
| `active_end_frame` | 攻撃判定を終了するフレーム。終了フレームも有効 |
| `hitbox_position` | 攻撃判定の位置。X は向いている方向へ反転する |
| `hitbox_size` | 攻撃判定の矩形サイズ |
| `sprite_scale` | 攻撃スプライトの表示倍率 |
| `sprite_offset` | 攻撃スプライトの表示位置補正 |

現在は 21 フレームを 24 FPS で再生し、内部フレーム 7～8 の 2 フレームだけ攻撃判定を有効にしています。
攻撃全体は約 0.875 秒、攻撃判定は約 0.083 秒です。

フレーム番号と秒数の関係は次のとおりです。

```text
秒数 = フレーム番号 / fps
```

例えば 24 FPS のフレーム 7 は約 0.292 秒後、フレーム 8 は約 0.333 秒後です。

## Pien敵の攻撃調整

対象ファイル: `data/motions/enemy_attack.tres`

| 項目 | 内容 |
| --- | --- |
| `damage` | プレイヤーに与える AP ダメージ |
| `prepare_frames` | 攻撃前の予備フレーム数 |
| `grow_frames` | panti 表示を拡大するフレーム数 |
| `active_start_frame` | 敵の攻撃判定開始フレーム |
| `active_end_frame` | 敵の攻撃判定終了フレーム |
| `recovery_end_frame` | 攻撃モーション終了フレーム |
| `cooldown_frames` | 攻撃後に再攻撃できるまでの物理フレーム数 |
| `hitbox_position` | パンチ画像と攻撃判定の位置 |
| `hitbox_size` | 敵の攻撃判定の矩形サイズ |

敵攻撃は物理フレームを基準に処理しています。通常の 60 FPS 環境では、`cooldown_frames = 180` は約 3 秒です。

## 判定の確認

ゲーム中に `P` キーを押すと、プレイヤーと敵の存在判定・くらい判定・攻撃判定を表示できます。

- 青: 存在判定
- 赤: くらい判定
- 黄: 有効中の攻撃判定

攻撃判定は有効フレームの間だけ黄色で表示されます。攻撃が当たらない場合は、まず `active_start_frame` / `active_end_frame`、`hitbox_position`、`hitbox_size` の順に確認してください。

## 検証

Git Bash で次のコマンドを実行します。

```bash
/g/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe \
  --headless --audio-driver Dummy --quit-after 300 \
  res://scenes/main.tscn test
```

次の条件を満たせば成功です。

- `SCRIPT ERROR`、`Parse Error`、`Failed to load` がない
- すべての `TEST [...]` が `PASS`
- `TEST SUMMARY: ALL PASS` が出力される
- 終了コードが 0

モーションデータを追加・変更した場合は、必要に応じて `scripts/main.gd` のモーション検証も更新します。