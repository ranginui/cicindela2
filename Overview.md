

# JP #

## URLを叩くだけの簡単なAPI ##

Cicindela は、MySQL上のデータと，それを参照する modperl の web API，そして計算処理を行う perl のバッチとで構成されています。 入出力は特定の URL に対してリクエストを送ることで行います。

Amazon の **「この商品を買った人はこの商品も買っています」** も、**「このページを見た人はこのページも見ています」** も、簡単にいうと

  1. **「ユーザ1が、アイテム2を選択した」, 「ユーザ3がアイテム4を選択した」, ...** というデータを蓄積する
  1. 上記のデータを元に、 **「アイテム2を選択した人は他に何番のアイテムを選択した ?」「ユーザ1へのおすすめアイテム番号は ?」 ...** という質問に答える

という形に一般化できます。

Cicindela に **「ユーザ1がアイテム2を選択した」** という情報を登録するには
```
  http://(ベースURL)/cicindela/record?set=(セット名)&op=insert_pick&user_id=1&item_id=2
```
というURLにリクエストを送るだけです。

また、Cicindela に **「ユーザ1にオススメするアイテムは ?」** という質問をするには
```
  http://(ベースURL)/cicindela/recommend?set=(セット名)&op=for_user&user_id=1
```
というURLにリクエストを送るだけです。結果は
```
  10
  12
  24
  ...
```
という改行区切りのidリストの形で返ります。上の結果は、 **「ユーザ1にオススメするのはアイテム10, アイテム12、アイテム24, ... 」** という意味です。


このように、Cicindela とそれを利用するアプリケーションとは、ユーザid、アイテムid などの簡単なid値のみでやりとりを行います。

アプリケーションは、適当なタイミング (ユーザが商品を購入したとか、特定のページを見たとか) でユーザidやアイテムidを送信し、レコメンデーションを表示したい時にまた同じidで問い合わせを行うだけです。

## 柔軟な内部構造 ##

「簡単な数字しかやりとりしない」イコール、「簡単な処理しかできない」のではありません。

「ユーザXがアイテムYを選択した」というデータの蓄積から、ユーザXに次に何をレコメンドするのか、を計算する方法については様々な実装方法があります。おすすめを決定するまでの処理は高度に抽象化されており、プラグイン形式で様々な計算方法を自在に組み合わせることができます。

Cicindela は、入力データを複数のモジュール (フィルタ) に順に通していきます。それぞれのフィルタは入力データに対してなんらかの処理を行い、次のフィルタに出力を渡します。最終的に、レコメンデーション出力に必要な集計が揃うと、新しい集計結果と古い集計結果が瞬時に入れ替えられます。この一連の処理を「Filter chain」と呼んでいます。

つまり、「入力データに対してなんらかの処理・変換を加えるフィルタ群」と、「その結果を利用してレコメンデーションを出力するレコメンダ」さえ揃っていれば、処理の中身は自由にカスタマイズできます。レコメンデーション以外の用途に使うことさえ可能です。


また、上の例で説明した単純な「ユーザXがアイテムYを選択した」タイプの情報以外にも、「ユーザXがアイテムYに○点をつけた」とか、タグ/カテゴリといった概念を扱うこともできます。詳しくは [FilterChain](FilterChain.md) [Examples](Examples.md) などを参照して下さい。


## 高速な応答 ##

  1. 中間集計をほとんど MySQL のメモリエンジン上に保持している。
  1. 複雑な計算はバックグラウンドで行い、すべての結果が揃ったところで一気に古いテーブルと新しいテーブルを入れ替える方式。つまり、解析系がAPI入出力から隔離されているため、ロックによるパフォーマンス低下などが起きにくい。

という設計上の特性があります。

既存の webサイトなどに気軽にレコメンデーションを追加することができ、それによるパフォーマンス上のデメリットはほとんどありません。

※フィルタやレコメンダは様々な実装が可能なのでそれ次第ではあるのですが，設計としては「バックグラウンドの計算時間は長めだけど，データの追加/取得は一瞬」という，反応速度重視の実装を得意とします。


# EN #

## simple web API ##

Cicindela is designed to input/output data via its web API, running on modperl. Data are stored on MySQL and are then periodically updated by calculation batch scripts.

Most recommendations seen on the web, such as amazon's "customers who bought this item also bought..", can be generalized as:

  1. accumulate data which are in the form **"user1 selected item2"**, **"user3 selected item4"**, etc.
  1. answer the questions such as **"which items would people select after selecting item3 ?"** or **"which items would you recommend for user 1 ?"**, based on the accumulated data.

To tell cicindela that **user 1 has selected item 2**, all you have to do is to make a GET request to the following URL:
```
  http://(base URL)/cicindela/record?set=(set name)&op=insert_pick&user_id=1&item_id=2
```

...and to ask cicindela **which items should be recommended to user 1**, you should call the following URL:
```
  http://(base URL)/cicindela/recommend?set=(set name)&op=for_user&user_id=1
```
the result is a simple new-line separated list of ids which looks something like this:
```
  10
  12
  24
  ...
```
The above list shows that **you should recommend items 10, 12, 14.. to user 1**.

Cicindela and its client application only exchange simple set of integer ids (i.e. item ids, user ids, category ids...).

All you need to do is to send an HTTP request on a certaion user action (purchasing,  cliking on a link etc), and later retrieve the recommendations using the same user id.

## flexible internal design ##

Dealing only with simple integer ids does not mean it has a simple functionality.

There are various algorithms to obtain recommendations from huge set of "who selected what"s.

Cicindela performs a set of calculations on its data, passing intermediate result of one analysis module to the next module until all the similarity matrices (or whatever it needs to emit the recommendations in one last step) are ready. Only then, all the necessary tables are swapped with old tables and made on-line.

This sequence is called "filter chain", and is built on a highly customizable plugin architecture. What kind of calculations and conversions a module (= filter) does, and how those filters are integrated, is left to your free will. (You don't even have to use this program for making recommendations !)

In addition to the simple "who selected whats" type of data mentioned above, cicindela can also handle data such as ratings, categories and tags.

Please refer to [FilterChain](FilterChain.md) [Examples](Examples.md) for details (document unfinished...)

## quick, non-locking response ##

Cicindela has a unique, practical design to keep its input/output interface light and fast:

  1. On-line tables (tables read by the recommenders) are kept on memory (using MySQL's memory engine).
  1. All anallysis are run in the background. On-line tables are instantly swapped with the new ones, only after all the new results are ready.  This separates the heavy weight analysis process from the input/output API.

You can easily add a recommendation service to an existing web service, without any extra performance disadvantages.

(Response speed depends on how the recommender is implemented. But cicindela basically suites best for situations where you want to keep on updating and at the same time retrieving the data, and can not sacrifice user experience for it)