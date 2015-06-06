

# JP #

ライブドア，あるいは他者が提供する，デモ用のデータセットを利用して動作確認をすることができます。

([Install](Install.md) を先に済ませてあることが前提です。)

**以下のデモセットアップを試す場合は，この操作で misc/ 以下を demo\_data ブランチに切り替えて下さい。**
```
 cd /home/cicindela
 svn switch http://cicindela2.googlecode.com/svn/branches/demo_data/misc misc
```
switch に成功すると，misc/clip\_data および misc/movielens\_data というディレクトリができます。ライブドアクリップのサンプルデータセット (約11M) が含まれるため，スイッチには多少の時間を要することがあります。

## livedoor clip dataset を使ったサンプルセットアップ ##

### データベース & テーブル作成 ###

cicindela は，集計セット毎に別々のデータベースを利用します。

misc/create\_init\_sql.pl --db\_name=**データベース名**

を叩くと、指定したデータベース名で、cicindela イニシャライズ用のsqlが標準出力に書き出されます。
例えば作成するデータベース名が cicindela\_clip\_db ，mysql のパスが /usr/local/mysql/bin/mysql である場合，以下のようにして新規データベースのセットアップができます。
```
 cd /home/cicindela/misc
 perl create_init_sql.pl --db_name=cicindela_clip_db | /usr/local/mysql/bin/mysql -uroot
```


専用のユーザを作成する場合は，以下のように同時に指定することも出来ます。
```
 perl create_init_sql.pl --db_name=cicindela_clip_db
     --grant_user=cicindela --grant_pass=japana --grant_host=% | /usr/local/mysql/bin/mysql -uroot 
```
この場合は，データベースとテーブルのセットアップに加えて
```
  grant all on cicindela_clip_db.* to "cicindela"@"%" identified by "japana";
  flush privileges;
```
が発行されます。

デフォルトのワイルドカードのユーザが権限設定をややこしくする場合があるので，必要に応じて
```
 SQL> drop user ""@"localhost";
 SQL> flush privileges;
```
などをしといた方がいいかもしれません。

### データのインポート ###

misc/clip\_data/importer.pl  --work\_dir=**テンポラリディレクトリ**

は、標準入力からライブドアクリップのデータCSV を受け取り、中間ファイルをテンポラリディレクトリに書き出したあと、その中間ファイルを読み込むための sql を標準出力へ書き出します。

以下のようにして、csv.gz ファイルをパースしてデータベースに読み込ませるまでの一連の処理をまとめて実行することができます。
```
 cd misc/clip_data
 gunzip -c ldclip_demo_dataset.csv.gz | perl importer.pl  --work_dir=`pwd` | /usr/local/mysql/bin/mysql -uroot cicindela_clip_db
```

※ローダースクリプトを利用するには perl モジュール Text::CSV\_XS が必要です。

※このスクリプトは中間データを work\_dir に書き出したあと「load data infile ... 」ステートメントを mysql に渡します。従って，work\_dir で指定するテンポラリディレクトリは mysql ユーザから参照可能である必要があります。

### 設定 ###

Cicindela の設定ファイルは **lib/Cicindela/Config/`_`common.pm** です。
この中に，clip のデータを利用するためのサンプル設定がコメントとして挿入されています。

該当部分 ("## sample settings for ldclip\_dataset " というコメントの直後から，"## sample
settings for movielens dataset " というコメントの直前まで) のコメントアウトを外して下さい。

必要に応じて，datasource => [ ] (データベース接続用の設定値) の行などを編集して下さい。

### clip\_simple 集計セットの手動起動 ###

```
 bin/batch.pl --track=1
```
を叩くと，設定ファイル中， "calculation\_track => 1" となっている集計セット  (この例では，' clip\_simple' という名前の集計セット) が処理されます。

ただし，初回  (=「前回の集計終了時刻」が空のとき) は何も起きませんので，上のコマンドを二回叩いて下さい。
ログは var/logs/log.txt に書き出されます。

log に "clip\_simple done." と表示されるまで待ちます。(ある程度時間がかります。)

### clip\_simple 集計セットの結果確認 ###

```
 /usr/local/apache2/bin/apachectl start
```
でmodperlを起動したあと，
```
  http://127.0.0.1/cicindela/recommend?op=for_item&set=clip_simple&item_id=39102
```
などを確認します。

正常に動いている場合は
```
 49425
 44936
 42886
 ...
```
といった，シンプルな改行区切りのidリスト表示になるはずです。これが，アイテムid=39102 のページに対するレコメンデーション (「このページを見ている人はこのページも見ています」) の結果です。

Cicindela はユーザやアイテムなどをすべて id値のみで扱っているので，それぞれの id が何を意味していたかは，cicindela を利用するアプリケーション側で知っておく必要があります。

(user\_id, item\_id に数値以外のものを指定する方法もありますが，基本的には，整数idを利用するように設計されています。)

「データのインポート」の手順の際に，misc/clip\_data 以下に pages.txt という中間ファイルが書き出されていますので，これを元にそれぞれのアイテムid が実際にはどの url を表しているのかを確認して下さい。

※ちなみにアイテムid 39102 は

> 「livedoor reader パーフェクトガイド - livedoor ディレクター Blog」http://blog.livedoor.jp/ld_directors/archives/50735409.html

です。
レコメンドのトップ2つのid 49425 と 44936 は、いずれも livedoor reader のメインの開発者のブログである  http://mala.nowa.jp/ 内のエントリでした。


### clip\_hybrid 集計セットの手動起動と確認 ###

上でコメントアウトした設定ファイルには，clip\_simple の他に clip\_tags, clip\_hybrid という二つの集計セットが定義されています。

clip\_tags は，tag\_id を user\_id にみたてて読み込むことにより，「同じユーザが選んでいるアイテム」のかわりに「同じタグがついているアイテム」をレコメンドするようにした変則的な集計セットです。
```
 bin/batch.pl --track=2
```
で，この集計を走らせることができます。(初回は2回叩く必要あり)

また，clip\_hybrid は、上記の「clip\_simple (通常の協調フィルタリング)」と「clip\_tags (タグベースの協調フィルタリング)」をだいたい6:4で混ぜ合わせて表示する，表示専用のセットです。
(clip\_simple と clip\_tags の集計が終わっていれば結果を表示できるので，clip\_hybrid 自体はバッチによる再集計を必要としません。)

```
  http://127.0.0.1/cicindela/recommend?op=for_item&set=clip_hybrid&item_id=39102
```
などで，異なる集計セットによるレコメンデーション結果を確認できます。

[Examples](Examples.md) の中で、clip で実際に使われている、タグベースのレコメンデーションや複数の結果を合成する方法の例が詳しく解説してあります。


### バッチの設定方法の捕捉 ###

上の2つの例で使った集計セットは，最初に [Install](Install.md) で設定した集計用バッチスクリプト ( etc/service/cicindela\_batch) では処理されません。

設定に calculation\_track => ... という指定のある集計セットは，明示的に --track= ... オプションを渡された時のみ処理されます。

calculation\_track の指定を外すか，
```
 sudo ln -s /home/cicindela/etc/service/cicindela_batch_track1 /service/cicindela_batch_track1
 sudo ln -s /home/cicindela/etc/service/cicindela_batch_track2 /service/cicindela_batch_track2
```
などとすることで，自動的に再計算を走らせることができるようになります。

batch.pl は集計セットを順にひとつずつ処理しますが，このようにすることで複数の集計セットのアップデートを同時に走らせることができるようになります。時間のかかる集計セットと，軽いけれど頻繁に更新する必要がある集計セットとを並列で走らせておく場合に使います。

※「refresh interval => (再計算が行われるまでの秒数)」の設定値が小さすぎると，無駄に高頻度で再計算をはじめるのでここも調整しておく必要があります。



## movielens dataset を使ったサンプルセットアップ ##

### データベース & テーブル作成 ###
```
 cd misc
 perl create_init_sql.pl --db_name=cicindela_movielens_db
     --grant_user=cicindela --grant_host=% --grant_pass=japana | /usr/local/mysql/bin/mysql -uroot
```

### データの取得と読み込み ###

以下のサイトからデータセット (1,000,000 Data Set) を取得します。

http://www.grouplens.org/node/73

解凍したデータを misc/movielens\_data/ 以下に置き，以下のようにしてロードします。。(読み込みに必要なのは ratings.dat のみです。)

```
 cd misc/movielens_data
 perl importer.pl --work_dir=`pwd` | /usr/local/mysql/bin/mysql -uroot cicindela_movielens_db
```

### 設定 ###

lib/Cicindela/Config/`_`common.pm の中に，movielens のデータを利用するためのサンプル設定がコメントとして挿入されています。

該当部分 ("## sample settings for movielens dataset " というコメントの直後にある 'movielens' => ... の部分) のコメントアウトを外して下さい。

※ 'movielens' セットアップは二つ定義されています。一つ目はごく一般的な、item間の類似度マトリックスを用いたアルゴリズム、もうひとつとは slope one を使ったアルゴリズムになっています。どちらか片方ずつをコメントアウトして試して下さい。

### movielens 集計セットの手動起動 ###

```
 bin/batch.pl --track=3
```
(初回は二回叩く必要あり)

log に "movielens done." と表示されるまで待ちます。

### movielens 集計セットの結果確認 ###
```
  http://127.0.0.1/cicindela/recommend?op=for_item&set=movielens&item_id=741
```
などで結果を確認できます。
```
3000
1274
29
...
```

clip のところでも述べたように，cicindela は基本的には id のみしか返しません。id と実際のタイトルの対応は，ダウンロードしたデータセット内にある movies.dat で確認して下さい。

ちなみに，上の例のアイテムid 741 は "Ghost in the shell (攻殻機動隊)"，id 3000= "Princess Mononoke (もののけ姫)",  id 1274 = "Akira ", id 29 = "City of Lost Children (ロストチルドレン)" です。

設定ファイルにある二つの設定例のうち，どちらを使うかでも変わってきますが，まあまあの結果じゃないでしょうか。



# EN #

A sample dataset from livedoor clip (a social bookmark service, mainly in Japanese) is included in the distribution. There also is a loader script and sample configurations to be used with grouplens dataset.

(Installation of prerequisites and cicindela basic setup should already be finshed. Please read [Install](Install.md) first.)

**switch the 'misc' directory to demo\_data branch by the following command, to retrieve the attached dataset or dataset loader scripts.**
```
 cd /home/cicindela
 svn switch http://cicindela2.googlecode.com/svn/branches/demo_data/misc misc
```

## sample setup with movielens dataset ##

### setup database and tables ###

Cicindela uses a separate database for each calculation set.
A new datbase "cindela\_movielens\_db" can easily be created and set up as follows:
```
 perl create_init_sql.pl --db_name=cicindela_movielens_db | /usr/local/mysql/bin/mysql -uroot 
```
Optionally, a mysql user (via which batch and modperl processes connect the database) can be created by specifying grant\_user, grant\_host and grant\_pass options.
```
 cd misc
 perl create_init_sql.pl --db_name=cicindela_movielens_db
     --grant_user=cicindela --grant_host=% --grant_pass=japana | /usr/local/mysql/bin/mysql -uroot
```
In the example above, the following sql is emitted in addition to the database initialization sql.
```
  grant all on cicindela_mobielens_db.* to "cicindela"@"%" identified by "japana";
  flush privileges;
```

You might better  delete some of the default wildcard name users, as their priorities often become very much confusing...
```
 SQL> drop user ""@"localhost";
 SQL> flush privileges;
```


### load dataset ###

Obtain the movielens dataset (1,000,000 Data Set) from the following site:

http://www.grouplens.org/node/73

place the unzipped files into 'misc/movieles\_data/' and then do:
```
 cd misc/movielens_data
 perl importer.pl --work_dir=`pwd` | /usr/local/mysql/bin/mysql -uroot cicindela_movielens_db
```
(actually, all you need is the 'ratings.dat' file).


### configuration ###

Cicindela's main configuration file is located at **lib/Cicindela/Config/`_`common.pm**.
This file contains two sample setups to be used with this movielens data. ('movielens' => ...part which appears directly after the line "## sample settings for movielens dataset")

Both setups are commented out by default. Former set uses a normal item-to-item similarity matrix, where the latter set uses slope one. Activate either of the two.

You may also have to edit the "datasource => ..." part to connect to the database.

### manually activate 'movielens' analysis ###

The following command will activate the analysis sequence.
```
 bin/batch.pl --track=3
```
You willl have to call this command twice, since the batch does nothing when it is run the first time (= when 'last\_processed' timestamp is null ).

'--track=3' option will tell the batch.pl script to process only the calculation sets which have "calculation\_track" vaiable set to "3".

Because of this, this setting 'movielens' is not processed automatically by the basic calculation batch (which should already have been installed in [Install](Install.md) ). Removing this line would cause the 'movielens' set to be re-calculated periodically.  (Remember to set the "refresh\_interval" value appropriately, or the batch will try to run the re-calculation in an uselessly high frequency).

All logs are written in var/logs/log.txt.
Wait until the line "movielens done." appears in the the log. It may take a while.

### retrieving results from 'movielens' set ###
You can retrieve item to item recommendation for item 741 by calling:
```
  http://127.0.0.1/cicindela/recommend?op=for_item&set=movielens&item_id=741
```
The result should look something like this:
```
3000
1274
29
...
```
The response is a simple ,newline-separated list of ids.

Basically, cicindela only deals with integer user ids and item ids. You should refer to the original data file 'movies.dat' to find out what the corresponding movies titles are.

In the above example, item id 741 was  "Ghost in the shell"，id 3000 ="Princess Mononoke" , id 1274= "Akira " and  id 29 = "City of Lost Children". Result may differ depending on which of the two settings you have selected, but this one seems pretty OK, doesn't it ?