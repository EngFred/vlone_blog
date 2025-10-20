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
import 'package:video_thumbnail/video_thumbnail.dart';

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
      String? thumbnailUrl;

      if (mediaFile != null) {
        if (mediaType == 'video') {
          final duration = await getVideoDuration(mediaFile);
          if (duration > Constants.maxVideoDurationSeconds) {
            AppLogger.warning(
              'Video duration exceeds limit: $duration seconds',
            );
            throw const ServerException('Video exceeds allowed duration');
          }
        }

        // Upload media file (video/image)
        mediaUrl = await _uploadFileToStorage(
          file: mediaFile,
          userId: userId,
          folder: 'posts/media',
        );

        // If it's a video, generate thumbnail locally and upload it
        if (mediaType == 'video') {
          final thumbPath = await _generateThumbnailFile(mediaFile);
          if (thumbPath != null) {
            final thumbFile = File(thumbPath);
            final thumbUrl = await _uploadFileToStorage(
              file: thumbFile,
              userId: userId,
              folder: 'posts/thumbnails',
            );
            thumbnailUrl = thumbUrl;
            try {
              // optional: delete local thumbnail after upload
              if (await thumbFile.exists()) {
                await thumbFile.delete();
              }
            } catch (_) {}
          }
        }
      }

      final postData = {
        'user_id': userId,
        'content': content,
        'media_url': mediaUrl,
        'media_type': mediaType ?? 'none',
        'thumbnail_url': thumbnailUrl,
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
      // If upload failed but we already copied file for background upload fallback, schedule background
      // (keep your existing Workmanager fallback logic if needed)
      throw ServerException(e.toString());
    }
  }

  // Helper to upload a file and return public url.
  Future<String> _uploadFileToStorage({
    required File file,
    required String userId,
    required String folder, // e.g., 'posts/media' or 'posts/thumbnails'
  }) async {
    final fileExt = file.path.split('.').last;
    final fileName = '${const Uuid().v4()}.$fileExt';
    final uploadPath = '$folder/$userId/$fileName';

    try {
      AppLogger.info('Uploading file to path: $uploadPath');
      // Supabase SDK: upload file
      await client.storage.from('posts').upload(uploadPath, file);
      final url = client.storage.from('posts').getPublicUrl(uploadPath);
      AppLogger.info('File uploaded successfully, url: $url');
      return url;
    } catch (e) {
      AppLogger.error(
        'Upload failed, scheduling background upload: $e',
        error: e,
      );
      // On failure, fallback to copying locally and scheduling Workmanager task.
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

  // Generate a thumbnail image file path from a local video file.
  Future<String?> _generateThumbnailFile(File videoFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
        maxHeight: 720, // keep reasonable size for preview
      );
      return thumbPath; // may be null if thumbnail couldn't be generated
    } catch (e) {
      AppLogger.error('Thumbnail generation failed: $e', error: e);
      return null;
    }
  }

  Future<List<PostModel>> getFeed() async {
    try {
      AppLogger.info('Fetching feed');
      final response = await client
          .from('posts')
          .select('*, profiles ( username, profile_image_url )')
          .order('created_at', ascending: false);
      AppLogger.info('Feed fetched with ${response.length} posts');
      return response.map((map) => PostModel.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('Error fetching feed: $e', error: e);
      throw ServerException(e.toString());
    }
  }

  Future<List<PostModel>> getUserPosts({required String userId}) async {
    try {
      AppLogger.info('Fetching user posts for $userId');
      final response = await client
          .from('posts')
          .select('*, profiles ( username, profile_image_url )')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      AppLogger.info('User posts fetched with ${response.length} posts');
      return response.map((map) => PostModel.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('Error fetching user posts: $e', error: e);
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
