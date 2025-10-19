import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/model/place.dart'; // Ensure the correct import path for the Place model

class PlaceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> addPlace(
    String name,
    double latitude,
    double longitude, {
    String? category,
    double notificationRadius = 100.0,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception("User not authenticated");
      }

      // Use the provided category if available, otherwise default to "none".
      Place place = Place(
        id: '', // Firestore will generate an ID
        userId: user.uid,
        name: name,
        category: category ?? 'none',
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        notificationRadius: notificationRadius,
      );

      await _firestore.collection('Places').add(place.toMap());
    } catch (e) {
      print('Error adding place: $e');
      throw Exception('Failed to add place: $e');
    }
  }

  Future<void> deletePlaceCompletely(String placeId) async {
    try {
      await _firestore.collection('Places').doc(placeId).delete();
      debugPrint('Place $placeId completely deleted from Firestore');
    } catch (e) {
      debugPrint('Error deleting place: $e');
      throw Exception('Failed to delete place: $e');
    }
  }

  Future<bool> shouldDeletePlace(Place place) async {
    try {
      // Only delete places that meet ALL these conditions:
      // 1. Not marked as favorite
      // 2. Has no category or category is 'none'
      // 3. Is NOT a home place (NEW: protect home places)
      // 4. Was created more than 24 hours ago (NEW: protect recent places)

      final bool isOldPlace = place.timestamp != null &&
          DateTime.now().difference(place.timestamp!).inHours > 24;

      return !place.isFavorite &&
          !place.isHome && // NEW: Don't delete home places
          (place.category.isEmpty || place.category == 'none') &&
          isOldPlace; // NEW: Only delete old places
    } catch (e) {
      print('Error checking if place should be deleted: $e');
      return false;
    }
  }

  Future<void> toggleFavorite(Place place) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not authenticated");

      // Check if this place already exists in Firestore
      final existingPlaceQuery = await _findExistingPlace(place);

      if (existingPlaceQuery.docs.isNotEmpty) {
        final existingDoc = existingPlaceQuery.docs.first;
        final data = existingDoc.data() as Map<String, dynamic>?;
        if (data != null) {
          final currentFavorite = data['isFavorite'] ?? false;
          final newFavoriteStatus = !currentFavorite;

          if (newFavoriteStatus) {
            // Adding to favorites - update the place
            await _firestore.collection('Places').doc(existingDoc.id).update({
              'isFavorite': true,
              'timestamp': FieldValue.serverTimestamp(),
            });
          } else {
            // Removing from favorites - check if we should delete the place entirely
            final currentCategory = data['category'] ?? '';
            if (currentCategory.isEmpty || currentCategory == 'none') {
              // No category assigned, delete the place completely
              await _firestore
                  .collection('Places')
                  .doc(existingDoc.id)
                  .delete();
            } else {
              // Still in a category, just update favorite status
              await _firestore.collection('Places').doc(existingDoc.id).update({
                'isFavorite': false,
                'timestamp': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      } else {
        // Create new place with favorite=true
        final newPlace = place.copyWith(
          userId: user.uid,
          isFavorite: true,
          timestamp: DateTime.now(),
          source: place.source,
        );
        await _firestore.collection('Places').add(newPlace.toMap());
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      throw Exception('Failed to toggle favorite: $e');
    }
  }

  // UPDATED: Toggle favorite with immediate deletion when removing
  Future<void> toggleFavoriteWithDeletion(Place place) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not authenticated");

      // Check if this place already exists in Firestore
      final existingPlaceQuery = await _findExistingPlace(place);

      if (existingPlaceQuery.docs.isNotEmpty) {
        final existingDoc = existingPlaceQuery.docs.first;
        final data = existingDoc.data() as Map<String, dynamic>?;

        if (data != null) {
          final currentFavorite = data['isFavorite'] ?? false;

          if (currentFavorite) {
            // Removing from favorites - DELETE COMPLETELY
            debugPrint(
                'Removing from favorites - deleting place ${existingDoc.id} completely');
            await _firestore.collection('Places').doc(existingDoc.id).delete();
          } else {
            // Adding to favorites - create/update the place
            final newPlace = place.copyWith(
              userId: user.uid,
              isFavorite: true,
              timestamp: DateTime.now(),
              source: place.source,
            );
            await _firestore.collection('Places').add(newPlace.toMap());
          }
        }
      } else {
        // Create new place with favorite=true
        final newPlace = place.copyWith(
          userId: user.uid,
          isFavorite: true,
          timestamp: DateTime.now(),
          source: place.source,
        );
        await _firestore.collection('Places').add(newPlace.toMap());
      }
    } catch (e) {
      debugPrint('Error toggling favorite with deletion: $e');
      throw Exception('Failed to toggle favorite: $e');
    }
  }

  Future<void> setHomePlace(String placeId, bool isHome) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not authenticated");

      // First, unset ANY existing home for this user
      final querySnapshot = await _firestore
          .collection('Places')
          .where('userId', isEqualTo: user.uid)
          .where('isHome', isEqualTo: true)
          .get();

      final batch = _firestore.batch();

      // Unset all existing homes
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isHome': false});
        print('🔄 Unsetting previous home: ${doc.id}');
      }

      // Set the new home place (only if isHome is true)
      final placeRef = _firestore.collection('Places').doc(placeId);
      if (isHome) {
        batch.update(placeRef, {'isHome': true});
        print('✅ Setting new home: $placeId');
      } else {
        batch.update(placeRef, {'isHome': false});
        print('❌ Removing home status: $placeId');
      }

      await batch.commit();
      print('🎯 Home status updated successfully');
    } catch (e) {
      print('Error setting home place: $e');
      throw Exception('Failed to set home place: $e');
    }
  }

  Future<Place?> getUserHome(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('Places')
          .where('userId', isEqualTo: userId)
          .where('isHome', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return Place.fromMap(
            querySnapshot.docs.first.id, querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error getting user home: $e');
      return null;
    }
  }

  Future<QuerySnapshot> _findExistingPlace(Place place) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    // Try to find by googlePlaceId first (for Google Places)
    if (place.googlePlaceId != null && place.googlePlaceId!.isNotEmpty) {
      return await _firestore
          .collection('Places')
          .where('userId', isEqualTo: user.uid)
          .where('googlePlaceId', isEqualTo: place.googlePlaceId)
          .limit(1)
          .get();
    }

    // Try to find by osmId (for OpenStreetMap places)
    if (place.osmId != null && place.osmId!.isNotEmpty) {
      return await _firestore
          .collection('Places')
          .where('userId', isEqualTo: user.uid)
          .where('osmId', isEqualTo: place.osmId)
          .limit(1)
          .get();
    }

    // Try to find by coordinates and name (fallback)
    return await _firestore
        .collection('Places')
        .where('userId', isEqualTo: user.uid)
        .where('latitude', isEqualTo: place.latitude)
        .where('longitude', isEqualTo: place.longitude)
        .where('name', isEqualTo: place.name)
        .limit(1)
        .get();
  }

  // NEW: Get favorite places
  Stream<List<Place>> getFavoritePlaces() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not authenticated");
    }

    return _firestore
        .collection('Places')
        .where('userId', isEqualTo: user.uid)
        .where('isFavorite', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Place.fromMap(doc.id, doc.data()))
            .toList());
  }

  // NEW: Add place to favorites (if it doesn't exist in Firestore)
  Future<void> addToFavorites(Place place) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception("User not authenticated");
      }

      // Check if place already exists in Firestore
      final existingPlaceQuery = await _firestore
          .collection('Places')
          .where('userId', isEqualTo: user.uid)
          .where('googlePlaceId', isEqualTo: place.googlePlaceId)
          .limit(1)
          .get();

      if (existingPlaceQuery.docs.isNotEmpty) {
        // Update existing place
        final existingDoc = existingPlaceQuery.docs.first;
        await _firestore.collection('Places').doc(existingDoc.id).update({
          'isFavorite': true,
        });
      } else {
        // Create new place with favorite=true
        final newPlace = place.copyWith(
          userId: user.uid,
          isFavorite: true,
          timestamp: DateTime.now(),
        );
        await _firestore.collection('Places').add(newPlace.toMap());
      }
    } catch (e) {
      print('Error adding to favorites: $e');
      throw Exception('Failed to add to favorites: $e');
    }
  }

  Future<Place?> getPlaceById(String placeId) async {
    try {
      final doc = await _firestore.collection('Places').doc(placeId).get();
      if (doc.exists) {
        return Place.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting place by ID: $e');
      return null;
    }
  }

  Future<bool> isPlaceFavorite(Place place) async {
    try {
      final existingPlaceQuery = await _findExistingPlace(place);
      if (existingPlaceQuery.docs.isNotEmpty) {
        final existingDoc = existingPlaceQuery.docs.first;
        final data =
            existingDoc.data() as Map<String, dynamic>?; // FIX: Cast to Map
        if (data != null) {
          return data['isFavorite'] ?? false;
        }
      }
      return false;
    } catch (e) {
      print('Error checking favorite status: $e');
      return false;
    }
  }

  Future<void> updateNotificationRadius(String placeId, double radius) async {
    try {
      await _firestore.collection('Places').doc(placeId).update({
        'notificationRadius': radius,
      });
    } catch (e) {
      print('Error updating notification radius: $e');
      throw Exception('Failed to update notification radius: $e');
    }
  }

  // Existing method: fetch places by category.
  Stream<List<Place>> getPlacesByCategory(String category) {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not authenticated");
    }

    return _firestore
        .collection('Places')
        .where('userId', isEqualTo: user.uid)
        .where('category', isEqualTo: category)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Place.fromMap(doc.id, doc.data()))
            .toList());
  }

  // New method: fetch all places (ignoring category).
  Future<List<Place>> getAllPlaces() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not authenticated");
    }
    QuerySnapshot snapshot = await _firestore
        .collection('Places')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => Place.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
  }

  // place_service.dart - Update getPlacesForSpace method
  Future<List<Place>> getPlacesForSpace(String spaceId) async {
    try {
      // Get all members in the space
      final spaceDoc = await _firestore.collection('Spaces').doc(spaceId).get();
      if (!spaceDoc.exists) return [];

      final members = List<String>.from(spaceDoc.data()?['members'] ?? []);
      final allPlaces = <Place>[];

      // Get places for each member in the space
      for (final memberId in members) {
        final placesSnapshot = await _firestore
            .collection('Places')
            .where('userId', isEqualTo: memberId)
            .get();

        for (final doc in placesSnapshot.docs) {
          final place = Place.fromMap(doc.id, doc.data());

          // Include ALL home places from ALL users in the space
          // Include ALL places from current user (both home and regular)
          if (place.isHome || memberId == _auth.currentUser?.uid) {
            allPlaces.add(place);
          }
        }
      }

      debugPrint('Loaded ${allPlaces.length} places for space $spaceId');
      return allPlaces;
    } catch (e) {
      print('Error getting places for space: $e');
      return [];
    }
  }

  Future<void> deletePlace(String placeId) async {
    try {
      await _firestore.collection('Places').doc(placeId).delete();
    } catch (e) {
      print('Error deleting place: $e');
      throw Exception('Failed to delete place: $e');
    }
  }

  // New method: update the category of a place.
  Future<void> updatePlaceCategory(String placeId, String newCategory) async {
    try {
      await _firestore.collection('Places').doc(placeId).update({
        'category': newCategory,
      });
    } catch (e) {
      print('Error updating place category: $e');
      throw Exception('Failed to update place category: $e');
    }
  }

  // New method: remove the place from its category (i.e. set its category to "none").
  Future<void> removePlaceFromCategory(String placeId) async {
    try {
      await updatePlaceCategory(placeId, 'none');
    } catch (e) {
      print('Error removing place from category: $e');
      throw Exception('Failed to remove place from category: $e');
    }
  }
}
