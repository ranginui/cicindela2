

# JP #

## シンプルな設定例 ##

  * 解析には Filters::PicksExtractor -> Filters::InverseUserFrequency -> Filters::ItemSimilarities を順に適用する。
  * レコメンドには (Filters::ItemSimilarities と対になっている) Recommender::ItemSimilarities を利用する
  * 一時間毎にレコメンデーションを再計算する
```
    'test' => {
        datasource =>  [ 'dbi:mysql:cicindela_test;host=localhost', 'cicindela', 'japana' ],
        filters => [
            'PicksExtractor',
            'InverseUserFrequency',
            'ItemSimilarities',
        ],
        recommender => 'ItemSimilarities',
        refresh_interval => 60 * 60 * 1,
    },
```

## フィルタのオプションを指定する ##

  * 各フィルタに引数を渡すことで、デフォルトの設定値(入出力テーブル名とか、係数とか)をオーバーライドできる。
  * 以下は、PicksExtractor フィルタの出力テーブルを "extracted\_picks" から "extracted\_picks2" に変更した例。PicksExtractor  フィルタの出力先がかわれば、その出力を利用する InverseUserFrequency フィルタや ItemSimilarities フィルタの入力もあわせて定義してやる必要がある点に注意。
```
    'test' => {
        datasource =>  [ 'dbi:mysql:cicindela_test;host=localhost', 'cicindela', 'japana' ],
        filters => [
            [ 'PicksExtractor', { out_table => 'extracted_picks2' } ],
            [ 'InverseUserFrequency', { in_table => 'extracted_picks2' } ],
            [ 'ItemSimilarities', { in_table => 'extracted_picks2' } ],
        ],
        recommender => 'ItemSimilarities',
        refresh_interval => 60 * 60 * 1,
    },
```

## 複数のセッティングを同居させる & 同時に複数のセッティングを並列で処理する ##

  * 各セッティングは独立した datasource を持つことができるので、複数のサービスに対するレコメンデーションを一カ所に同居させられる。
  * 後の例にもあるように、おなじサービスに対するレコメンデーションを異なる設定で複数出力させ、最後に合成する、といったこともできる。
  * slave\_datasource を定義しておけば、(読み出し専用の) Recommender クラスはスレーブ側を使ってくれる。
  * ただし、解析は単一の batch.pl プロセスが順番に行っているため、解析に時間がかかるセッティングが多数定義してあると、refresh\_interval の通りの間隔で更新が行われないこともある。
  * ひとつの解析に大量のメモリ/CPUリソースが使われるため、単純に batch.pl を同時に複数実行するのは解決にはならない。インプリメンテーション(lock の仕組みとか) 的にも、そのような状況は想定していない。
  * そういうのが必要な場合にはcalculation\_track というオプションを利用する。例えば calculation\_track=>1と calculation\_track=>2 の二つを定義し、二種類の batch.pl  (それぞれ--track=1 , --track=2 オプション付き) を並列実行させておくと、最大二つの解析を並走させられる。時間がかかる処理をtrack1に、軽量で高頻度に更新しなければならない処理をtrack2に振り分けておけば、track1の処理が長考に入ってもtrack2側は影響を受けない。
  * 以下は、 実際に clip で使っている例。3時間毎に更新される 「clip」が track1 で走っている裏で、「clip\_express」が track2 で10分毎に走っている。
  * ※clip も clip\_express も同じ datasource を使っているので、clip が picks->extracted\_picks->iuf->item\_similarities->item\_similarities\_online という中間テーブルを順次利用するのに対して、clip\_express 側は picks->extracted\_picks2->iuf2->item\_similarities\_ex->item\_similarities\_ex\_online というふうに使うテーブルを分けているのに注意。
```
    'clip' => {
        datasource =>  [ 'dbi:mysql:clip;host=master-host', 'cicindela', 'japana' ],
        slave_datasource =>  [ 'dbi:mysql:clip;host=slave-host', 'cicindela', 'transbaicalica' ],
        filters => [
            [ 'PicksExtractor', {
                interval => '3 month',
                in_table => 'picks',
                out_table => 'extracted_picks',
            } ],
            [ 'InverseUserFrequency', {
                in_table => 'extracted_picks',
                out_table => 'iuf',
            } ],
            [ 'ItemSimilarities', {
                in_table => 'extracted_picks',
                in_table_iuf => 'iuf',
                out_table => 'item_similarities',
            } ],
        ],
        recommender => [ 'ItemSimilarities', { in_table => 'item_similarities_online' } ],
        refresh_interval => 60 * 60 * 3,
        calculation_track => 1,
    },
 
    'clip_express' => {
        datasource =>  [ 'dbi:mysql:clip;host=master-host', 'cicindela', 'japana' ],
        slave_datasource => [ 'dbi:mysql:clip;host=slave-host', 'cicindela', 'transbaicalica' ],
        filters => [
            [ 'PicksExtractor', {
                interval => '3 month',
                in_table => 'picks',
                out_table => 'extracted_picks2',
            } ],
            [ 'InverseUserFrequency', {
                in_table => 'extracted_picks2',
                out_table => 'iuf2'
            } ],
            [ 'ItemSimilarities::Express', {
                recent_interval => '1 day',
                in_table => 'extracted_picks2',
                in_table_iuf => 'iuf2',
                out_table => 'item_similarities_ex',
            } ],
        ],
        recommender => [ 'ItemSimilarities', { in_table => 'item_similarities_ex_online' } ],
        refresh_interval => 60 * 10,
        calculation_track => 2,
    },
```


## 複数のセッティングで計算したレコメンデーション結果を合成する。 ##

  * Recommender::Hybrid クラスは、複数のセッティングを合成するために使う。
  * 合成したいセッティング名と、factor(係数) を settings オプションに順に書いておく。
  * 各セッティングが出力したレコメンデーション結果に、それぞれのfactorが掛け合わされて合成される。片方のfactorが0.6, もう一方が0.4なら、結果が6:4の重みで合成されるということ。
  * 各セッティングは上から順に評価され、「有効なレコメンデーションが得られたセッティングのfactorの合計」が1を超えたら、そこで評価は終了する。つまり、すべてのfactorを1にすると、「一番上のセッティングで結果が得られなければ次のセッティングを使う。それでも結果が空ならその次のセッティングを...」という意味になる。
  * 下は clip の本番で利用している設定。
    * - セッティング「clip\_hybrid\_stage2」の結果を優先的に利用する。もしclip\_hybrid\_stage2の結果が空なら、セッティング「clip\_express」の結果を利用する。
    * - 一方、「clip\_hybrid\_stage2」はそれ自体がセッティング「clip」と「clip\_tags」の結果を6:4で合成したhybrid。
  * 結局、動作としては「『clip (通常のレコメンデーション)』と『clip\_tags (タグから算出したレコメンデーション)』の結果を6:4で合成したもの (『clip\_hybrid\_stage2』) を使う。ただし、それが得られない場合は『clip\_express (直近のデータだけを対象に、高速に、高頻度にレコメンデーションを再計算するモード) 』の結果を使う」となる。
```
    'clip_hybrid' => {
        datasource =>  [ 'dbi:mysql:clip;host=master-host', 'cicindela', 'japana' ],
        slave_datasource => [ 'dbi:mysql:clip;host=slave-host', 'cicindela', 'transbaicalica' ],
        recommender => [ 'Hybrid', {
            settings => [
                { factor => 1, set_name => 'clip_hybrid_stage2' },
                { factor => 1, set_name => 'clip_express' },
            ]
        } ],
    },
 
    'clip_hybrid_stage2' => {
        datasource =>  [ 'dbi:mysql:clip;host=master-host', 'cicindela', 'japana' ], 
        slave_datasource => [ 'dbi:mysql:clip;host=slave-host', 'cicindela', 'transbaicalica' ],
        recommender => [ 'Hybrid', {
            settings => [
                { factor => 0.6, set_name => 'clip' },
                { factor => 0.4, set_name => 'clip_tags' },
            ]
        } ],
    },
```

## user id と item id を整数ではなく文字列で入出力する ##

セッティングに
```
    'some_setting' => {
       ...
        use_user_char_id => 1,
        use_item_char_id => 1,
      ...
```
と書いておくと，整数値以外の user id, item id が利用できるようになります。

この場合は数値idと文字列idの変換テーブルをcicindela側で持つことになります。user id や item id が無限に増えてしまう可能性がある場合 (例えば，アクセスログの cookie値をユーザid として入力し，おすすめページを生成する場合など) は，古すぎる変換テーブルを破棄するように
```
       ...
        discard_user_id_char2int => '1 year',
        discard_item_id_char2int => '1 year',
      ...
```
といった設定をいれておくことを推奨します。上の例は 1年で破棄する設定です。('1 year' のところは，mysql の interval 指定で使う文字列を指定します。)

具体例は↓の「レコメンデーションの候補をカテゴリで絞る」のところを参照してください。


## レコメンデーションの候補をカテゴリで絞る ##

  * Recommender::ItemSimilarities::LimitCategory を使うと，リクエストで指定したカテゴリのみが推薦候補になる。
  * Recommender::ItemSimilarities::SameCategoryOnly を使うと、item to item レコメンデーションの場合に，元のアイテムのカテゴリと同じカテゴリに所属するアイテムのみが推薦候補になる。

前者は，「アダルトカテゴリにはアダルトの商品しか出しちゃダメ！」というふうに，推薦する範囲を表示時に厳しく制限したい場合用。

後者は，例えばお店のレコメンドをするときに「同じ最寄り駅」とか「同じジャンル」の店を優先して表示したい場合用。


以下は，

  * user id と item id が整数値ではなく文字列で送られて来る
  * アイテムは1つ以上のカテゴリに所属する
  * ユーザはアイテムにレーティングをつける
  * 最新100万件のレーティング情報を元に，Slope one アルゴリズムで類似度マトリックスを生成
  * レコメンデーション取得時に同時にカテゴリidも送信し，そのカテゴリに属するアイテムのみを推薦対象にする。
  * 肥大化を防ぐため，レーティング情報，および，user id の整数値 <=> 文字列値の内部変換テーブルは1年で破棄する。

というセッティングの例。(これも，あるサイトで実際に使用しているセッティングを多少簡略化したもの。)

```
    'limit_category' => {
        datasource =>  [ 'dbi:mysql:cicindela;host=master-host', 'cicindela', 'japana' ],

        use_user_char_id => 1,
        use_item_char_id => 1,

        discard_user_id_char2int => '1 year',
        discard_ratins => '1 year',

        filters => [
            'CopyPicks::WithRatings',
            'RatingsConverter::ZScore',
            'RatingsConverter::InverseUserFrequency',
            ['PicksExtractor::WithRatings', { in_table => 'converted_ratings', use_simple_set => 1, limit => 1000000 } ],
            'SlopeOneDiffs',
        ],
        recommender => 'SlopeOneDiffs::LimitCategory',
        refresh_interval => 60 * 60 * 1,
    },
```

## 別サーバ上の apache ログをスキャンして、おすすめページを計算する [あとで書く] ##
## タグを考慮したレコメンデーション [あとで書く] ##
## ただのランキングから，マニアックに偏ったオススメまで [あとで書く] ##
## 「興味がありません」の実装 [あとで書く] ##
## 古くなったデータを自動的に削除する [あとで書く] ##
## MySQL をマスターとスレーブに分割する [あとで書く] ##
## webAPI を使わずに、perlから直接利用する [あとで書く] ##

# EN #

wow  I have to translate all these...