

# JP #

## 基本のきまりごと ##

  * ユーザid, アイテムid などはすべて整数。サービス側であらかじめ付与し、int(11) を超える可能性がある場合はラウンド処もしておく
    * ※ user id に mod\_usertrack のcookie値や文字列のuser idをそのまま使いたい場合用に、cicindela側で文字id->数値id変換をやってくれる機能も一応あります。

  * Cicindela は複数のレコメンデーションサービス (「セット」) を扱うことができるので、リクエストには対象の  **「集計セット名」** を必ずつける。

## データの蓄積 ##

ユーザがアイテムを選択したり評価をつけた場合に、以下のURLに対してGETリクエストを投げて下さい。成功時には空のレスポンス(204 NO CONTENT) が返ります。エラーの場合は 400系のレスポンス(たいてい 400 BAD REQUEST か 404 NOT FOUND) が返ります。

以下の3種類の操作が可能です。

### 「あるユーザがあるアイテムを選択した」 ###

ユーザがあるアイテムを「clipした」とか「訪問した」というように、ユーザが明示的にレーティングを行わないタイプの場合はこのフォーマット。
```
  http://[base_url]/record?set=[セット名]&op=insert_pick&user_id=[ユーザid]&item_id=[アイテムid]
```
※ base\_url は初期状態では http://localhost/cicindela です。

**↓↑サービスの性質にあわせて、これか、下の「あるユーザがあるアイテムをに○点の評価をつけた」のどちらか一方のみを選択して使います。**
**ひとつの集計セットでratingsとpicks両方を使っても意味はありません。**

### 「あるユーザがあるアイテムをに○点の評価をつけた」 ###

ユーザが明示的に点数をつけるタイプの場合は以下のフォーマットを使う。rate は整数。
```
 http://[base_url]/record?set=[セット名]&op=insert_rating&user_id=[ユーザid]&item_id=[アイテムid]&rating=[評価]
```

### 「あるユーザがあるアイテムにあるタグをつけた」 ###

タグベースのレコメンデーションを利用する場合は、以下のリクエストを利用する。(タグベースのレコメンデーションは、tag id を擬似的な user id に見立てて読み込むことで実現される。[Demos](Demos.md), [Examples](Examples.md) などを参照のこと)
```
 http://[base_url]/record?set=[セット名]&op=insert_tag&user_id=[ユーザid]&item_id=[アイテムid]&tag_id=[タグid]
```


## その他の各種データ操作 ##

### 「あるアイテムをあるカテゴリに所属させる」 ###
※カテゴリは、中身的にはタグとほとんど同じもの。ただし，以下の点でタグと異なる働きをします。

  * タグと違って、ユーザは関係なし。「このアイテムがこのカテゴリに所属する」という関係性だけ。
  * 「同じカテゴリに所属するアイテムだけを候補にする」「指定したカテゴリのアイテムだけを候補にする」といったタイプのRecommender が選べる。

```
 http://[base_url]/record?set=[セット名]&op=set_category&item_id=[アイテムid]&category_id=[カテゴリid]
```
タグと同じような構造なので、ひとつのアイテムに複数のカテゴリを割り当ててもOK

### 「あるユーザがあるアイテムに[興味ありません]マークをつけた」 ###
  * 単にレコメンド結果から取り除かれるだけで，「マイナスの評価をつける」のと同じではありません。
  * レコメンダによってはサポートしていない場合があります。
  * そもそも，レーティング済/選択済のアイテムもおすすめには含まれないので，可能な限りこちらではなく insert\_pick/insert\_rating の方を使うべきです。
  * 反映されるまでに少しタイムラグがあるので，アプリケーション側でもセッションに情報をもっておいて，表示から隠すなどしたほうがよいでしょう。

```
 http://[base_url]/record?set=[セット名]&op=insert_uninterested&user_id=[ユーザid]&item_id=[アイテムid]
```


### セットしたデータを取り消す ###
```
 http://[base_url]/record?set=[セット名]&op=delete_pick&user_id=[ユーザid]&item_id=[アイテムid]

 http://[base_url]/record?set=[セット名]&op=delete_rating&user_id=[ユーザid]&item_id=[アイテムid]

 http://[base_url]/record?set=[セット名]&op=delete_tag&user_id=[ユーザid]&item_id=[アイテムid]&tag_id=[タグid]

 http://[base_url]/record?set=[セット名]&op=delete_uninterested&user_id=[ユーザid]&item_id=[アイテムid]

 http://[base_url]/record?set=[セット名]&op=remove_category&item_id=[アイテムid]&category_id=[カテゴリid]
```


## レコメンデーション取得 ##

レコメンデーションを取得するには、以下のURLに対してリクエストを投げてください。おすすめアイテムのidが、 関連の高い順に改行区切りテキスト形式で返されます。

### 特定アイテムに対するレコメンデーション(関連アイテム)取得 (=item to item) ###

関連アイテムのidをデフォルトで10件まで返します。
```
 http://[base_url]/recommend?set=[セット名]&op=for_item&item_id=[アイテムid]
```

### 特定ユーザに対するレコメンデーション取得 (=user to item) ###

指定したユーザに対するおすすめをデフォルトで20件まで返します。そのユーザがすでに選択済み(/評価済み) のアイテムはおすすめに含まれません。
```
 http://[base_url]/recommend?set=[セット名]&op=for_user&user_id=[ユーザid]
```

### お隣ユーザ取得 (user to user) ###

指定したユーザに似たユーザをデフォルトで20件まで返します。
```
 http://[base_url]/recommend?set=[セット名]&op=similar_users&user_id=[ユーザid]
```

### item to item / user to item / user to user に共通の決まりごと ###

上記のパラメータに加えて、以下をオプションで指定することができます。
  * &limit=件数 : 結果の最大件数を指定できます
  * &category=カテゴリid : 使用しているレコメンダによっては、これを指定することでレコメンデーションの範囲を特定のカテゴリに絞ることができます。

レコメンダによっては、上記の三種類のレコメンデーションの一部をサポートしていないことがあります。その場合は常に空のセットが返ります。

例えば、アイテム同士の類似度マトリックスしかもっていないレコメンダの場合、user to user の結果を返すメソッドが用意されていないか、あってもパフォーマンスが著しく劣ることがあります。(レコメンダの仕組みについては [WritingFilters](WritingFilters.md) あたりを参照して下さい。)




# EN #

## Common rules ##

  * All ids (user id, item id, etc) are in integers. You should also round them up if the ids have possibilty of going beyond the range of int(11).
    * There are options where you can use character user ids and item ids insted of integers.

  * Cicindela can handle multiple instances of recommendations, or **sets**. A **set name** is given for each set of calculations, and must be specified in each request.

## Accumulating data ##

Send a HTTP GET request each time a user selects an item, or rates an item. An empty response (204 NO CONTENT) is returned on success, 400 BAD REQUEST or 404 NOT FOUND on failure.

There are three basic accumulation requests.

### An user has selected an item ###

Make this request each time an user has selected an item (added an item to the basket, clicked on a link, etc).
```
  http://[base_url]/record?set=[set name]&op=insert_pick&user_id=[user id]&item_id=[item id]
```
(base\_url is http://localhost/cicindela by default.)


### An user has given an item a rating of N ###

Make this request each time an user rates an item. Rating should also be an integer.
```
 http://[base_url]/record?set=[set name]&op=insert_rating&user_id=[user id]&item_id=[item id]&rating=[rating]
```

**The above two operations, insert\_pick and insert\_rating can not co-exist in one set. Choose either of the two, depending on characteristics of the target service.**

### An user has tagged an item ###

Cicindela can make recommendations based on tags. Tag ids should also be integers. (Tag-based recommendation is achieved by assuming tag ids as pseudo user ids. No semantics are taken into concideration. See [Demos](Demos.md) and [Examples](Examples.md) for details)
```
 http://[base_url]/record?set=[set name]&op=insert_tag&user_id=[user id]&item_id=[item id]&tag_id=[tag id]
```

## Other data manipulations ##

### Associating an item to a category ###
Categories are not much different from tags, except for the following:
  * A tag involves both an item and an user. Categories are associated with items only.
  * Some recommenders can take an optional category-id parameter to "limit the recommendations to items of a certain category" or to "limit the recommendations to items which share the same category in common".

```
 http://[base_url]/record?set=[set name]&op=set_category&item_id=[item id]&category_id=[category id]
```
An item can belong to more than one categories.

### An user is "not interested" in an item ###
  * The item is excluded from the user's recommendations. This does not have the same effect as making negative ratings. The item is simply filtered out from the result.
  * Not all recommenders support this functionality.
  * Avoid using this function if you could use insert\_pick/insert\_rating instead, as already selected/rated items are excluded from recommendations anyway.
  * There is a certain delay until the insert buffer is flushed and the desired exclusion takes effect. Client application should also cache the same information on its own session, if the item should strictly be hidden from the user immediately.

```
 http://[base_url]/record?set=[set name]&op=insert_uninterested&user_id=[user id]&item_id=[item id]
```


### Delete the informations set by the above calls ###
```
 http://[base_url]/record?set=[set name]&op=delete_pick&user_id=[user id]&item_id=[item id]

 http://[base_url]/record?set=[set name]&op=delete_rating&user_id=[user id]&item_id=[item id]

 http://[base_url]/record?set=[set name]&op=delete_tag&user_id=[user id]&item_id=[item id]&tag_id=[tag id]

 http://[base_url]/record?set=[set name]&op=delete_uninterested&user_id=[user id]&item_id=[item id]

 http://[base_url]/record?set=[set name]&op=remove_category&item_id=[item id]&category_id=[category id]
```


## Getting recommendations ##

Make this request to retrieve a recommendation. A list of recommended ids are returned in the order of relevance, each separated by a new-line.

### item-to-item recommendation ###
10 recommended item ids for the specified item are returned by default.
```
 http://[base_url]/recommend?set=[set name]&op=for_item&item_id=[item id]
```

### user-to-item recommendation ###
20 recommended item ids for the specified user are returned by default. Items already selected (rated) by the user are excluded from the result.
```
 http://[base_url]/recommend?set=[set name]&op=for_user&user_id=[user id]
```

### user-to-user recommendation ###
20 user ids similar to the specified user are returned by default.
```
 http://[base_url]/recommend?set=[set name]&op=similar_users&user_id=[user id]
```

### rules common to all of the three recommendations ###
Optionally, following parameters may be available.
  * &limit=maximum number of recommendations
  * &category=category-id : some recommenders take this optional parameter, which puts a certain restriction on the result.

Some recommenders do not support all of the above three recommendations. An empty set is returned on such cases.

For example, a recommender which works only on an item-to-item similarity matrix does not have the user-to-user recommendation method implemeted, or, does not perform well even if it has. (See [WritingFilters](WritingFilters.md) for more detailed information on recommenders.)