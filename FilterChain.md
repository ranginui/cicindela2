

# JP #

## 基本 ##

Cicindelaが受け取るデータのうち，もっとも基本になるのは以下の二つのうちの **いずれか一方** 。
  * picks (あるユーザがあるアイテムを選択した、という情報。ユーザが選択するかしないかの二択で、点数をつけない場合はこちらのみを使う)
  * ratings (あるユーザがあるアイテムを選択し、ある点数をつけた、という情報。ユーザが点数を入力することができる場合はこちらのみを使う)

Id はすべて整数値。従って，cicindela とそれを利用するアプリケーションの間では基本的にidだけがやりとりされるため，シンプルでかつ汎用性が高い。

オプションとして，整数以外のユーザid/アイテムidも扱うことができる。この場合は、user\_id\_char2int, item\_id\_char2int という変換テーブルによって，入出力の手前で内部id <=> オリジナルid の変換が行われる。

これに加えて，以下の情報も扱うことができる。
  * tagged\_relations (あるユーザがあるアイテムに、あるidのタグをつけた、という情報)
  * categories (あるアイテムが、あるカテゴリidに所属する、という情報)
  * uninterested (あるユーザのレコメンド結果から，あるアイテムを除外してほしい，という情報)

それらのデータを各種フィルタに通して順次変換していき、最終的にアイテム間の類似度データを作るのが解析の心臓部にあたる「filter chain」

結果を返すために参照されるテーブルは，オンライン用 (表) と裏の二つのテーブルがセットになっている。解析は裏側でやっておき，バッチ処理が終了したら一気に rename table で二つのテーブルをいれかえる仕組み。入力バッファも解析バッチからは隔離されているため，web api は，解析用に走っている重いsqlの影響をうけない。



## 解析のながれ ##
```
 嗜好データ入力
  
 ↓ (Handlers/Record.pm が http経由で受け取ったデータを IncomingData.pm にわたす)
 
 入力バッファ
 picks_buffer, ratings_buffer, ...
  
 ↓ (bin/flush_buffer.pl により定期的にバッファがフラッシュされる)
 
 一次(生)データ
 picks, ratings, tagged_relations, ...
 
 ↓ (batch.pl から FilterChain.pm が呼ばれ，Filters/ 以下の各種プラグインフィルタが順に適用される)
 
 二次(中間)データ
 converted_ratings, extracted_ratings, iuf, ...

 集計結果テーブル
 item_similarities, slope_one_diffs, ...
 
 ↓ (集計がすべて終わったら、rename table により一挙に古いテーブルと入れ替わる)
 
 オンラインテーブル
 converted_ratings_online, item_similarities_online, slope_one_diffs_online, ...
 
 ↓ (Handlers/Recommend.pm が Recommender/ 以下の各種レコメンダの結果を http経由で出力)
 
 レコメンデーション出力
```

APIで受信した嗜好データは、それぞれ以下のテーブルに格納される。
  * 「このuser\_idがこのitem\_idを選択した」→ picks
  * 「このuser\_idがこのitem\_idにこの評価をつけた」→ratings
  * 「このuser\_idがこのitem\_idにこのtag\_idをつけた」→tagged\_relations
  * 「このitem\_idはこの category\_id に所属する」→categories
  * 「このuser\_idはこのitem\_idに興味がない」→uninterested

※実際には、競合防止のため、いったん picks\_buffer などのバッファに格納され、bin/flush\_buffers.pl が定期的にバッファの内容を本テーブルに移動している。

※また、数値ではないuser\_id /item\_id を内部用の数値idにマッピングする処理もこのバッファ内で行われる。[詳細はあとで書く]

定期的に、config の定義に従って、複数のフィルタが順に起動される。フィルタは Cicindela::Filters の子クラスで、それぞれ「あるテーブルからデータを読み出し、あるテーブルに書き出す」という動作をする。

> 例えば...

  * PicksExtractor フィルタは、picks テーブルから重要度順 (最新順とか、ユーザ数の多いアイテム順とか) に○件のデータを選択し、extracted\_picks テーブルに格納する。
  * InverseUserFrequency フィルタは、extracted\_picks テーブルからアイテム毎のユーザ数を集計し、iuf テーブルに inverse user frequency 値 (スコアリング時に、ユーザの多いデータにスコアが偏るのを補正するために使う) を書き出す。
  * ItemSimilarities フィルタは、extracted\_picks テーブルと iuf テーブルのデータから、アイテム間の類似度を item\_similarities テーブルに書き出す。

全てのフィルタリングが終了すると、Recommender が利用するテーブル(ここでは、最終段のフィルタが書き出した item\_similarities テーブル) は item\_similarities\_online という名前に変更される。それ以外の中間テーブル、および、それまであった item\_similarities\_online テーブルの内容は破棄される。

レコメンド出力APIは、Cicindela::Recommender の子クラスのどれかを使って出力される。

例えば Recommender::ItemSimilarities クラスは Filters::ItemSimilarities と対になっており、Filters::ItemSimilarities が書き出した類似度データ (item\_similarities\_online テーブル) を元に item別のレコメンドを計算する。
  * user 別のレコメンドは、上記のテーブルの他に picks / ratings テーブルに保存された嗜好データ (もしくは、converted\_picks /converted\_ratings に保存された正規化ずみ嗜好データ) をくみあわせて計算される。
  * item\_to\_item, user\_to\_item, user\_to\_user は、それぞれ、レコメンダの recommend\_for\_item(), recommend\_for\_user(),similar\_users() という名前のメソッドを呼び出すことで出力される。レコメンダによってはこれらの一部が実装されていないことがある。

### 現在実装されているフィルタとレコメンダ ###

→ [あとで書く]

### config の書き方の例 ###

→ [Examples](Examples.md)