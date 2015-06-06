
# JP #

## チェックアウト ##
```
 cd /home
 svn checkout http://cicindela2.googlecode.com/svn/trunk/ cicindela
```
インストール用のスクリプトは(いまのところ)ありません。プログラムはワーキングディレクトリ上で直接動作します。

諸般の事情により，**cicindela のチェックアウトディレクトリ = /home/cicindela , perl = /usr/bin/perl** がハードコードされている部分があります。

別のディレクトリにチェックアウトした場合や，perl のパスが違う場合は，以下のスクリプトでソースファイル内のハードコード部分を上書き置換することができます。(...もっとマシな方法をそのうち考えたいです。)
```
 cd misc
 perl substitute_project_paths.pl --perl_path=/usr/local/bin/perl --cicindela_home=/where/you/have/checkedout/cicindela
```
※以降、 **"/home/cicindela"** はすべて cicindela のチェックアウトディレクトリに置き換えて読み進めて下さい。

## mysql (>=5.0)  のインストール ##

以下のサイトからmysqlを取得し，インストールします。
  * http://dev.mysql.com/downloads/mysql/5.1.html

### mysqlの設定 ###

```
 ln -s /home/cicindela/etc/mysql/my.cnf /usr/local/mysql/my.cnf
```
※ディレクトリは環境によって変わる場合があります。

## perl モジュールのインストール ##

perl はたいていインストール済だと思いますが，バージョンが5.8以上であることを確認して下さい。
他に以下のモジュールを手動でインストールする必要があります。

  * DBI
  * DBD::mysql
  * Ima::DBI
  * Time::Piece
  * Log::Log4perl
  * Module::Pluggable
  * Class::Singleton

(またはこんな感じで..)
```
 sudo perl -MCPAN -e "install DBI; install DBD::mysql; install Ima::DBI;
    install Time::Piece; install Log::Log4perl;
    install Module::Pluggable; install Class::Singleton;" 
```

## apache + modperl のインストール ##

以下のサイトに従って apache とmodperl をインストールします。

  * http://httpd.apache.org/download.cgi
  * http://perl.apache.org/download/index.html

### modperl の設定 ###

以下の行を apache の設定ファイル httpd.conf の最後に追加します。
```
 Include /home/cicindela/etc/httpd/modperl.conf
```
※ディレクトリは環境によって変わる場合があります。

## daemontoolsのインストール ##

**※daemon tools は，入力バッファをフラッシュしたり，定期的に新しいデータで中間集計テーブルを再計算させるために使います。従って，新たなデータが次々に入ってこない場合 ( [Demos](Demos.md) の例など，固定のデータセットを読み込ませて結果を見るだけの場合など) はこのステップをスキップしても問題ありません。**

以下のサイトからdaemontoolsを取得し，インストールします。
  * http://cr.yp.to/daemontools/install.html


### daemontoolsの設定 ###

分析用のメインバッチ
```
 sudo ln -s /home/cicindela/etc/service/cicindela_batch /service/cicindela_batch
```

データの挿入用バッファをフラッシュするバッチ
```
 sudo ln -s /home/cicindela/etc/service/cicindela_flush_buffers /service/cicindela_flush_buffers
```

## ログの設定 ##

全てのログは (apache handler のものも，batch のものも) /home/cicindela/var/logs/log.txt に書き出されます。

ログの内容は /home/cicindela/etc/log.conf を編集することでカスタマイズできます。詳しくは Log::Log4perl のドキュメントを参照して下さい。

ログファイルは apache と batch の両方から読み書き可能である必要があります。以下をやっておいた方が安全かもしれません。
```
 touch /home/cicindela/var/logs/log.txt
 chmod a+rw /home/cicindela/var/logs/log.txt
```

ログをローテートしたい場合は，以下を /etc/logrotate.conf に追加するなどして下さい。
```
 /home/cicindela/var/logs/log.txt {
   daily
   create 0666 (user) (group)
   rotate 2
 }
```

## 次に ##

「このページを読んだ人は次に [Demos](Demos.md) も読んでいます」

# EN #

## checkout cicindela ##

```
 cd /home
 svn checkout http://cicindela2.googlecode.com/svn/trunk/ cicindela
```
**Program runs directly on the working directory.** No installation scripts (currently).

**Cicindela assumes project root dir = /home/cicindela** and **perl binary = /usr/bin/perl**, and are hard coded in the source codes.

If you happen to have checked out the source code in directories other than '/home/cicindela', or have perl installed somewhere other than '/usr/bin/perl', there still is a work around.

The script 'misc/substitute\_project\_paths.pl' can search and replace all occurences of those paths in-place. (yes, we know it's absurd)
```
 cd misc
 perl substitute_project_paths.pl --perl_path=/usr/local/bin/perl --cicindela_home=/where/you/have/checkedout/cicindela
```
All occurences of **"/home/cicindela"** in this document should be interpreted as your cicindela's checkout path.

## install mysql (>=5.0) ##

Follow the instructions on
  * http://dev.mysql.com/downloads/mysql/5.1.html

### configure mysql ###
```
 ln -s /home/cicindela/etc/mysql/my.cnf /usr/local/mysql/my.cnf
```

cicindela and mysql's local conf paths may be different depending on your installation.

## install perl prerequisite modules ##

(You'd most likely have perl already. just make sure it is above ver 5.8).

  * DBI
  * DBD::mysql
  * Ima::DBI
  * Time::Piece
  * Log::Log4perl
  * Module::Pluggable
  * Class::Singleton

install the following modules by hand

(or do something like..)
```
 sudo perl -MCPAN -e "install DBI; install DBD::mysql; install Ima::DBI;
    install Time::Piece; install Log::Log4perl;
    install Module::Pluggable; install Class::Singleton;" 
```

## install apache + modperl ##

Follow the instructions in the following pages:
  * http://httpd.apache.org/download.cgi
  * http://perl.apache.org/download/index.html

### setup modperl conf ###

Add the following line at the end of httpd.conf
```
 Include /home/cicindela/etc/httpd/modperl.conf
```

cicindela's path may be different depending on your installation.

## install daemontools ##

**(daemontools is used to flush input buffers, and to periodically kick the main calculation batch to refresh the pre-calculated tables. You may skip this part if you are not expecting further incoming data, or just trying to run an analysis on a fixed dataset such as the ones in [Demos](Demos.md) page)**

Follow the instructions on:
  * http://cr.yp.to/daemontools/install.html

### setup daemontools ###

main calculation batch
```
 sudo ln -s /home/cicindela/etc/service/cicindela_batch /service/cicindela_batch
```

insert buffer flusher
```
 sudo ln -s /home/cicindela/etc/service/cicindela_flush_buffers /service/cicindela_flush_buffers
```

## setup log ##

All logs (from batch scripts and modperl handlers) are written into /home/cicindela/var/logs/log.txt.

Log level and format can be configured by editing /home/cicindela/etc/log.conf.
Please refer to Log::Log4perl's documentation for details.

The log file must be accessible by both apache and batch. You may need to do the following:
```
 touch /home/cicindela/var/logs/log.txt
 chmod a+rw /home/cicindela/var/logs/log.txt
```


To rotate the logs daily, you can add
```
 /home/cicindela/var/logs/log.txt {
   daily
   create 0666 (user) (group)
   rotate 2
 }
```
in /etc/logrotate.conf.

## next ##

We recommend proceeding to [Demos](Demos.md), for a quick start using demo datasets.