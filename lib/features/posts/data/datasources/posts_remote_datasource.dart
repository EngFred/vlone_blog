import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/utils/helpers.dart';
import 'package:vlone_blog_app/features/posts/data/models/post_model.dart';
import 'package:workmanager/workmanager.dart';

class PostsRemoteDataSource {
  final SupabaseClient client;

  PostsRemoteDataSource(this.client);

  Future<PostModel> createPost({
    required String userId,
    String? content,
    File? mediaFile,
    String? mediaType,
  }) async {
    try {
      String? mediaUrl;
      if (mediaFile != null) {
        if (mediaType == 'video') {
          final duration = await getVideoDuration(mediaFile);
          if (duration > Constants.maxVideoDurationSeconds) {
            throw const ServerException('Video exceeds 10 minutes');
          }
        }
        mediaUrl = await _uploadMedia(mediaFile, userId, mediaType!);
      }

      final postData = {
        'user_id': userId,
        'content': content,
        'media_url': mediaUrl,
        'media_type': mediaType ?? 'none',
      };

      final response = await client
          .from('posts')
          .insert(postData)
          .select()
          .single();

      return PostModel.fromMap(response);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<String> _uploadMedia(
    File file,
    String userId,
    String mediaType,
  ) async {
    final fileExt = file.path.split('.').last;
    final fileName = '${const Uuid().v4()}.$fileExt';
    final uploadPath = 'posts/$userId/$fileName';

    try {
      await client.storage.from('posts').upload(uploadPath, file);
      return client.storage.from('posts').getPublicUrl(uploadPath);
    } catch (e) {
      // Schedule background upload
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$fileName';
      await file.copy(tempPath);

      Workmanager().registerOneOffTask(
        'upload_post_media_$fileName',
        'upload_media',
        inputData: {
          'bucket': 'posts',
          'uploadPath': uploadPath,
          'filePath': tempPath,
        },
      );
      throw ServerException('Upload started in background: $e');
    }
  }

  Stream<List<PostModel>> getFeedStream() {
    return client
        .from('posts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(Constants.pageSize)
        .map((list) => list.map((map) => PostModel.fromMap(map)).toList());
  }

  Future<List<PostModel>> getFeed({int page = 1, int limit = 20}) async {
    try {
      final from = (page - 1) * limit;
      final to = from + limit - 1;

      final response = await client
          .from('posts')
          .select()
          .order('created_at', ascending: false)
          .range(from, to);

      return response.map((map) => PostModel.fromMap(map)).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<void> likePost({
    required String postId,
    required String userId,
    required bool isLiked,
  }) async {
    try {
      if (isLiked) {
        await client.from('likes').delete().match({
          'post_id': postId,
          'user_id': userId,
        });
      } else {
        await client.from('likes').insert({
          'post_id': postId,
          'user_id': userId,
        });
      }
      // Triggers handle count updates
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<void> sharePost({
    required String postId,
    required String shareUrl,
  }) async {
    try {
      await Share.share(shareUrl);

      // Read current shares_count, increment it, then update the row
      final readResponse = await client
          .from('posts')
          .select('shares_count')
          .eq('id', postId)
          .single();
      final currentCount = (readResponse['shares_count'] != null)
          ? (readResponse['shares_count'] as int)
          : 0;
      await client
          .from('posts')
          .update({'shares_count': currentCount + 1})
          .eq('id', postId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
