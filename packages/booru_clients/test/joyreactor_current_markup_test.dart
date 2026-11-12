import 'package:booru_clients/joyreactor.dart';
import 'package:test/test.dart';

void main() {
  test('parses current JoyReactor content markup', () {
    const parser = JoyreactorHtmlParser();

    final result = parser.parsePage('''
<div class="content" id="postContainer9012345">
  <div class="post-author">
    <a href="/user/demo">
      <img alt="DemoUploader" src="https://img.joyreactor.com/avatar/user/42/avatar.jpg">
    </a>
  </div>
  <a href="/post/9012345">open post</a>
  <div class="post-content">
    <a href="https://img.joyreactor.com/pics/post/full/example-9012345.jpg">
      <img src="https://img.joyreactor.com/pics/post/example-9012345.jpg" width="640" height="480">
    </a>
  </div>
  <div class="post-tags">
    <a href="/tag/animation">animation</a>
  </div>
  <div class="post-footer"></div>
</div>
''');

    expect(result.posts, hasLength(1));
    final post = result.posts.single;
    expect(post.id, 9012345);
    expect(post.postUrl, 'https://joyreactor.com/post/9012345');
    expect(post.authorName, 'DemoUploader');
    expect(post.authorId, 42);
    expect(post.tags.map((tag) => tag.name), contains('animation'));
    expect(post.media, hasLength(1));
    expect(
      post.media.single.originalUrl,
      'https://img.joyreactor.com/pics/post/full/example-9012345.jpg',
    );
  });

  test('canonicalizes an old .cc configuration to joyreactor.com', () {
    expect(
      JoyreactorClient.normalizeBaseUrl('https://joyreactor.cc/'),
      'https://joyreactor.com',
    );
  });
}
