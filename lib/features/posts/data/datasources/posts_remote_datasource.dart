import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/error/exceptions.dart';
import 'package:vlone_blog_app/core/utils/app_logger.dart';
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
      AppLogger.info('Attempting to create post for user: $userId');
      String? mediaUrl;
      if (mediaFile != null) {
        if (mediaType == 'video') {
          final duration = await getVideoDuration(mediaFile);
          if (duration > Constants.maxVideoDurationSeconds) {
            AppLogger.warning(
              'Video duration exceeds limit: $duration seconds',
            );
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

      AppLogger.info('Post created successfully with ID: ${response['id']}');
      return PostModel.fromMap(response);
    } catch (e) {
      AppLogger.error('Error creating post: $e', error: e);
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
      AppLogger.info('Uploading media to path: $uploadPath');
      await client.storage.from('posts').upload(uploadPath, file);
      final url = client.storage.from('posts').getPublicUrl(uploadPath);
      AppLogger.info('Media uploaded successfully: $url');
      return url;
    } catch (e) {
      AppLogger.error(
        'Media upload failed, starting background upload: $e',
        error: e,
      );
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

  Future<List<PostModel>> getFeed({int page = 1, int limit = 20}) async {
    try {
      AppLogger.info('Fetching feed for page: $page, limit: $limit');
      final from = (page - 1) * limit;
      final to = from + limit - 1;

      final response = await client
          .from('posts')
          .select('*, profiles ( username, profile_image_url )')
          .order('created_at', ascending: false)
          .range(from, to);

      AppLogger.info('Feed fetched with ${response.length} posts');
      return response.map((map) => PostModel.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('Error fetching feed: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  Future<void> likePost({
    required String postId,
    required String userId,
    required bool isLiked,
  }) async {
    try {
      AppLogger.info(
        'Attempting to ${isLiked ? 'like' : 'unlike'} post: $postId by user: $userId',
      );
      if (isLiked) {
        await client.from('likes').insert({
          'post_id': postId,
          'user_id': userId,
        });
      } else {
        await client.from('likes').delete().match({
          'post_id': postId,
          'user_id': userId,
        });
      }
      AppLogger.info('Like/unlike successful for post: $postId');
    } catch (e) {
      AppLogger.error('Error liking post: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  Future<void> sharePost({required String postId}) async {
    try {
      AppLogger.info('Attempting to share post: $postId');
      final shareUrl = 'Check this post: https://yourapp.com/post/$postId';
      await Share.share(shareUrl);

      final readResponse = await client
          .from('posts')
          .select('shares_count')
          .eq('id', postId)
          .single();
      final currentCount = (readResponse['shares_count'] as int?) ?? 0;
      await client
          .from('posts')
          .update({'shares_count': currentCount + 1})
          .eq('id', postId);
      AppLogger.info('Post shared and count updated successfully');
    } catch (e) {
      AppLogger.error('Error sharing post: $e', error: e);
      throw ServerException(e.toString());
    }
  }
}
