import 'package:accessability/accessability/logic/bloc/place/bloc/place_event.dart';
import 'package:accessability/accessability/logic/bloc/place/bloc/place_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:accessability/accessability/data/model/place.dart';
import 'package:accessability/accessability/data/repositories/place_repository.dart';

class PlaceBloc extends Bloc<PlaceEvent, PlaceState> {
  final PlaceRepository placeRepository;

  PlaceBloc({required this.placeRepository}) : super(PlaceInitial()) {
    on<AddPlaceEvent>(_onAddPlaceEvent);
    on<GetAllPlacesEvent>(_onGetAllPlacesEvent);
    on<GetPlacesByCategoryEvent>(_onGetPlacesByCategoryEvent);
    on<DeletePlaceEvent>(_onDeletePlaceEvent);
    on<UpdatePlaceCategoryEvent>(_onUpdatePlaceCategoryEvent);
    on<RemovePlaceFromCategoryEvent>(_onRemovePlaceFromCategoryEvent);
    on<UpdatePlaceNotificationRadiusEvent>(
        _onUpdatePlaceNotificationRadiusEvent);
    on<ToggleFavoritePlaceEvent>(_onToggleFavoritePlaceEvent);
    on<CheckFavoriteStatusEvent>(_onCheckFavoriteStatusEvent);
    on<GetFavoritePlacesEvent>(_onGetFavoritePlacesEvent);
    on<AddToFavoritesEvent>(_onAddToFavoritesEvent);
    on<DeletePlaceCompletelyEvent>(_onDeletePlaceCompletelyEvent);
    on<CleanupOrphanedPlacesEvent>(_onCleanupOrphanedPlacesEvent);
    on<ToggleFavoriteWithDeletionEvent>(_onToggleFavoriteWithDeletionEvent);
  }

  Future<void> _onAddPlaceEvent(
      AddPlaceEvent event, Emitter<PlaceState> emit) async {
    emit(PlaceOperationLoading());
    try {
      await placeRepository.addPlace(
        event.name,
        event.latitude,
        event.longitude,
        category: event.category, // Optional category passed if available.
      );

      // After adding, fetch all places again to refresh the list
      final places = await placeRepository.getAllPlaces();
      emit(PlacesLoaded(places));
    } catch (e) {
      emit(PlaceOperationError('Failed to add place: ${e.toString()}'));
    }
  }

  Future<void> _onDeletePlaceCompletelyEvent(
      DeletePlaceCompletelyEvent event, Emitter<PlaceState> emit) async {
    emit(PlaceOperationLoading());
    try {
      await placeRepository.deletePlaceCompletely(event.placeId);

      // Refresh all places to update the UI
      final places = await placeRepository.getAllPlaces();
      emit(PlacesLoaded(places));
    } catch (e) {
      emit(PlaceOperationError('Failed to delete place: ${e.toString()}'));
    }
  }

  // NEW: Toggle favorite with immediate deletion
  Future<void> _onToggleFavoriteWithDeletionEvent(
      ToggleFavoriteWithDeletionEvent event, Emitter<PlaceState> emit) async {
    emit(PlaceOperationLoading());
    try {
      await placeRepository.toggleFavoriteWithDeletion(event.place);

      // Refresh all places to update the UI
      final places = await placeRepository.getAllPlaces();
      emit(PlacesLoaded(places));
    } catch (e) {
      emit(PlaceOperationError('Failed to toggle favorite: ${e.toString()}'));
    }
  }

  Future<void> _onCleanupOrphanedPlacesEvent(
      CleanupOrphanedPlacesEvent event, Emitter<PlaceState> emit) async {
    emit(PlaceOperationLoading());
    try {
      final places = await placeRepository.getAllPlaces();
      int deletedCount = 0;

      for (final place in places) {
        final shouldDelete = await placeRepository.shouldDeletePlace(place);
        if (shouldDelete) {
          await placeRepository.deletePlaceCompletely(place.id);
          deletedCount++;
        }
      }

      // Refresh places after cleanup
      final updatedPlaces = await placeRepository.getAllPlaces();
      emit(PlacesLoaded(updatedPlaces));

      debugPrint('Cleaned up $deletedCount orphaned places');
    } catch (e) {
      emit(PlaceOperationError('Failed to cleanup places: ${e.toString()}'));
    }
  }

  Future<void> _onGetAllPlacesEvent(
      GetAllPlacesEvent event, Emitter<PlaceState> emit) async {
    emit(PlaceOperationLoading());
    try {
      final places = await placeRepository.getAllPlaces();
      emit(PlacesLoaded(places));
    } catch (e) {
      emit(PlaceOperationError('Failed to load all places: ${e.toString()}'));
    }
  }

  Future<void> _onGetPlacesByCategoryEvent(
      GetPlacesByCategoryEvent event, Emitter<PlaceState> emit) async {
    emit(PlaceOperationLoading());
    try {
      await emit.forEach<List<Place>>(
        placeRepository.getPlacesByCategory(event.category),
        onData: (places) => PlacesLoaded(places),
        onError: (error, stackTrace) =>
            PlaceOperationError('Failed to load places: ${error.toString()}'),
      );
    } catch (e) {
      emit(PlaceOperationError('Failed to get places: ${e.toString()}'));
    }
  }

  Future<void> _onToggleFavoritePlaceEvent(
      ToggleFavoritePlaceEvent event, Emitter<PlaceState> emit) async {
    emit(PlaceOperationLoading());
    try {
      await placeRepository.toggleFavorite(event.place);

      // Get the updated favorite status
      final isFavorite = await placeRepository.isPlaceFavorite(event.place);

      // Emit the favorite toggled state for immediate UI feedback
      emit(PlaceFavoriteToggled(place: event.place, isFavorite: isFavorite));

      // Then refresh all places to ensure consistency
      final places = await placeRepository.getAllPlaces();
      emit(PlacesLoaded(places));
    } catch (e) {
      emit(PlaceOperationError('Failed to toggle favorite: ${e.toString()}'));
    }
  }

  // FIXED: Check favorite status
  Future<void> _onCheckFavoriteStatusEvent(
      CheckFavoriteStatusEvent event, Emitter<PlaceState> emit) async {
    try {
      final isFavorite = await placeRepository.isPlaceFavorite(event.place);
      emit(PlaceFavoriteStatusChecked(isFavorite: isFavorite));
    } catch (e) {
      emit(PlaceOperationError(
          'Failed to check favorite status: ${e.toString()}'));
    }
  }

  // NEW: Get favorite places event handler
  Future<void> _onGetFavoritePlacesEvent(
      GetFavoritePlacesEvent event, Emitter<PlaceState> emit) async {
    emit(PlaceOperationLoading());
    try {
      // Use getAllPlaces and filter client-side for now to avoid Firestore index issues
      final allPlaces = await placeRepository.getAllPlaces();
      final favoritePlaces =
          allPlaces.where((place) => place.isFavorite).toList();
      emit(PlacesLoaded(favoritePlaces));
    } catch (e) {
      emit(PlaceOperationError('Failed to load favorites: ${e.toString()}'));
    }
  }

  // NEW: Add to favorites event handler
  Future<void> _onAddToFavoritesEvent(
      AddToFavoritesEvent event, Emitter<PlaceState> emit) async {
    emit(PlaceOperationLoading());
    try {
      await placeRepository.addToFavorites(event.place);

      // Refresh all places
      final places = await placeRepository.getAllPlaces();
      emit(PlacesLoaded(places));
    } catch (e) {
      emit(PlaceOperationError('Failed to add to favorites: ${e.toString()}'));
    }
  }

  Future<void> _onDeletePlaceEvent(
      DeletePlaceEvent event, Emitter<PlaceState> emit) async {
    emit(PlaceOperationLoading());
    try {
      await placeRepository.deletePlace(event.placeId);

      // After deleting, fetch all places again to refresh the list
      final places = await placeRepository.getAllPlaces();
      emit(PlacesLoaded(places));
    } catch (e) {
      emit(PlaceOperationError('Failed to delete place: ${e.toString()}'));
    }
  }

  Future<void> _onUpdatePlaceCategoryEvent(
      UpdatePlaceCategoryEvent event, Emitter<PlaceState> emit) async {
    emit(PlaceOperationLoading());
    try {
      await placeRepository.updatePlaceCategory(
          event.placeId, event.newCategory);

      // After updating, fetch all places again to refresh the list
      final places = await placeRepository.getAllPlaces();
      emit(PlacesLoaded(places));
    } catch (e) {
      emit(PlaceOperationError(
          'Failed to update place category: ${e.toString()}'));
    }
  }

  Future<void> _onRemovePlaceFromCategoryEvent(
      RemovePlaceFromCategoryEvent event, Emitter<PlaceState> emit) async {
    emit(PlaceOperationLoading());
    try {
      await placeRepository.removePlaceFromCategory(event.placeId);

      // After removing from category, fetch all places again to refresh the list
      final places = await placeRepository.getAllPlaces();
      emit(PlacesLoaded(places));
    } catch (e) {
      emit(PlaceOperationError(
          'Failed to remove place from category: ${e.toString()}'));
    }
  }

  Future<void> _onUpdatePlaceNotificationRadiusEvent(
      UpdatePlaceNotificationRadiusEvent event,
      Emitter<PlaceState> emit) async {
    emit(PlaceOperationLoading());
    try {
      await placeRepository.updateNotificationRadius(
          event.placeId, event.radius);

      // After updating radius, fetch all places again to refresh the list
      final places = await placeRepository.getAllPlaces();
      emit(PlacesLoaded(places));
    } catch (e) {
      emit(PlaceOperationError(
          'Failed to update notification radius: ${e.toString()}'));
    }
  }
}
