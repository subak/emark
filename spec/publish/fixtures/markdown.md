
![](http://everblog.cdn-cache.com/shard/s8/res/e441e988-a021-4053-a237-756443d827b9/4f4e3a45c7049.jpeg)

このブログにエントリーページをTwitterでツイートするボタンと、Facebookでいいね！するボタンを設置した時に行ったことのまとめです。 
a-blog cms の使用を想定していますが、一部の情報は他のブログでも応用できると思います。 
スクリプトをテンプレートに直接記述するのではなくjsで出力するようにしているところがポイントです。


##Twitterボタンをゲット##
Twitterにログインして下記のページへアクセス 
[Twitter / Twitterボタン](http://twitter.com/about/resources/tweetbutton "Twitter / Twitterボタン")
![](http://everblog.cdn-cache.com/shard/s8/res/c91649ed-7a40-42af-b8bb-9b4cb4be566f/)

ボタンを選択

![](http://everblog.cdn-cache.com/shard/s8/res/e7fd3763-9cec-46b0-a112-a2d8a828fafe/)

##Like Buttonをゲット##
Facebookにログインして下記のページへアクセス 
[Like Button - Facebook開発者](http://developers.facebook.com/docs/reference/plugins/like/ "Like Button - Facebook開発者")



![](http://everblog.cdn-cache.com/shard/s8/res/ceb03934-83ab-4243-a79e-f226259a266d/)

URL to LIKE
: 特定のURLに対して「いいね！」する場合はURLを指定する。なければ設置されているページのURL

Send Button (XFBML Only)
: 友達などにお知らせするための「送る」ボタンを表示する

Layout Style
: レイアウトや表示される内容を選べる

Width
: 設置する場所に併せて好みの横幅を指定できる

Show Faces
: Layout Styleでstandardを選んでいるときに「いいね！」しているユーザーのアイコンを表示

Verb to display
: ボタンのラベルを「いいね！」から「おすすめ！」に変更できる

Color Scheme
: 見た目の色を選べる

Font
: フォントを選べる


**Get Code** ボタンを押すとソースコードが表示される。

![](http://everblog.cdn-cache.com/shard/s8/res/7ff36dfa-f619-491f-bc17-7300f6fc66b9/)

##a-blog cms に設置##
ツイートボタンもライクボタンも、ボタンのHTML要素とは別にスクリプトを読み込む必要があります。 
私はJavascriptを直接テンプレートに書くのが嫌だったので[**index.js**](http://www.tk84.net/blog/a-blog%20cms%20%E3%81%A7%E3%82%B9%E3%83%9E%E3%83%BC%E3%83%88%E3%81%AB%20js%20(%20JavaScript%20)%20%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB%E3%82%92%E7%AE%A1%E7%90%86%E3%81%99%E3%82%8B/ "a-blog cms でスマートに js ( JavaScript ) ファイルを管理する")から読み込むことにしました。 

> [a-blog cms でスマートに js ( JavaScript ) ファイルを管理する](http://www.tk84.net/blog/a-blog%20cms%20%E3%81%A7%E3%82%B9%E3%83%9E%E3%83%BC%E3%83%88%E3%81%AB%20js%20(%20JavaScript%20)%20%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB%E3%82%92%E7%AE%A1%E7%90%86%E3%81%99%E3%82%8B/ "a-blog cms でスマートに js ( JavaScript ) ファイルを管理する")





    /**
     * index.js
     */
    jsDir = $('#user-js').attr('src').replace(/index\.js$/, '');

    $(document).ready(function ( )
    {
      // twitter
      !function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0];if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src="//platform.twitter.com/widgets.js";fjs.parentNode.insertBefore(js,fjs);}}(document,"script","twitter-wjs");

      // facebook
      $('body').append('<div id="fb-root"></div>');
      (function(d, s, id) {
        var js, fjs = d.getElementsByTagName(s)[0];
        if (d.getElementById(id)) return;
        js = d.createElement(s); js.id = id;
        js.src = "//connect.facebook.net/ja_JP/all.js#xfbml=1";
        fjs.parentNode.insertBefore(js, fjs);
      }(document, 'script', 'facebook-jssdk'));
    }


次にテンプレートに実際に表示されるボタンのHTML要素をコピペします。 
私はblogテーマを継承させたテーマを使用しているのですが、blogテーマにはそれらしい箇所がはじめから記述してありました。


    <!-- **/themes/blog/index.htmlのそれっぽい箇所** -->

                        <!-- BEGIN footer:veil -->
                        <footer>
                             <p class="entryFooter">Posted by {posterName} at <time>{date#H}:{date#i}</time> | <a href="{inheritUrl}">Permalink</a>
                            <!-- BEGIN commentAmount --> | <a href="{commentUrl}#comment">comment ( {commentAmount} )</a><!-- END commentAmount --></p>
                             <!--#include file="/include/snsButton.html"-->
                        </footer>
                        <!-- END footer:veil -->
                   </article>



使用しているテーマに**/include/snsButton.html**というファイルを用意してそこにボタンのHTML要素をコピペします。

    <!-- **/include/snsButton.html** -->

    <!-- BEGIN_MODULE Touch_Entry -->
    <!-- twitter --><a href="https://twitter.com/share" class="twitter-share-button" data-via="_tk84" data-lang="ja">ツイート</a>
    <br />
    <!-- facebook --><div class="fb-like" data-send="false" data-width="450" data-show-faces="true"></div>
    <!-- END_MODULE Touch_Entry -->


###スタイルの問題###

これで無事動いたのですが、いいね！ボタンを押した時に表示されるポップアップが隠れてしまっていました。

![](http://everblog.cdn-cache.com/shard/s8/res/8a52b009-9084-40d2-a47e-f060921148da/)

次のようにスタイルを修正しました。

    .entry {
         /* overflow:hidden; */
         overflow: visible;
    }

##参考リンク##
[Facebook Likeボタン（いいね！）を設置。仕様。](http://memorva.jp/memo/api/facebook_like_recommend_button.php "Facebook Likeボタン（いいね！）を設置。仕様。")
[Twitter公式ツイートボタンを設置](http://memorva.jp/memo/api/twitter_tweet_button.php "Twitter公式ツイートボタンを設置")

##まとめと考察##
ボタンを設置する際のスクリプトをテンプレートに直接記述するのではなくjsで出力するようにしました。
簡単なjsの知識は必要になりますがこうすることでテンプレートのメンテナンスが楽になります。




