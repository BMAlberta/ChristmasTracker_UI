//
//  AsyncListMiddleware.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/10/25.
//

import Foundation

protocol ListActionHandling {
    func process(_ action: ListActions, dispatch: @escaping (any Action) -> Void)
}

struct ListActionHandler: ListActionHandling {
    private let apiService: APIServiceProviding
    
    init(apiService: APIServiceProviding) {
        self.apiService = apiService
    }
    
    func process(_ action: ListActions, dispatch: @escaping (any Action) -> Void) {
        switch action {
        case .addList(let newList):
            Task {
                do {
                    let _ = try await apiService.listAPI.createList(newList: newList)
                    await MainActor.run {
                        dispatch(ListActions.addListSuccess)
                    }
                } catch let error as ListError {
                    dispatch(ListActions.addListError(error))
                }
                catch {
                    await MainActor.run {
                        dispatch(ListActions.addListError(ListError.unknown))
                    }
                }
            }
        case .addListSuccess:
            dispatch(ListActions.loadHomeFeed)
        case .addListError(_):
            break
        case .addListFlowComplete:
            break
        case .deleteList:
            break
        case .deleteListSuccess:
            break
        case .viewListDetails(_):
            break
        case .resetListDetails:
            break
        case .addItem(newItemDetails: var newItemDetails, listInContext: let listInContext):
        Task {
                do {
                    let imageUrl = await ImageUtiliy.fetchImagePathForItem(urlString: newItemDetails.itemLink)
                    newItemDetails.itemImageUrl = imageUrl
                    let _ = try await apiService.itemAPI.addNewItem(toList: listInContext, newItem: newItemDetails)
                    dispatch(ListActions.addItemSuccess)
                } catch let error as ListError {
                    await MainActor.run {
                        dispatch(ListActions.addItemError(.unknown))
                    }
                } catch {
                    await MainActor.run {
                        dispatch(ListActions.addItemError(.unknown))
                    }
                }
            }
            
        case .addItemSuccess:
            dispatch(ListActions.loadHomeFeed)
        case .addItemError(_):
            break
        case .addItemFlowComplete:
            break
        case .purchaseItem(listInContext: let listId, itemId: let itemId, quantityPurchased: let quantityPurchased, purchasePrice: let purchasePrice):
            Task {
                do {
                    let _ = try await apiService.itemAPI.markItemPurchased(listId: listId,
                                                                                          itemInContext: itemId,
                                                                                          quantityPurchased:
                                                                                            quantityPurchased,
                                                                                          purchasePrice: purchasePrice)
                    await MainActor.run {
                        dispatch(ListActions.purchaseItemSuccess)
                    }
                } catch let _ as ListError {
                    await MainActor.run {
                        dispatch(ListActions.purchaseItemError(.unknown))
                    }
                } catch {
                    await MainActor.run {
                        dispatch(ListActions.purchaseItemError(.unknown))
                    }
                }
            }
        case .purchaseItemSuccess:
            Task {
                await MainActor.run {
                    dispatch(ListActions.loadHomeFeed)
                }
            }
        case .purchaseItemError(_):
            break
        case .purchaseFlowComplete:
            break
        case .retractItem(listId: let listId, itemId: let itemId):
            Task {
                do {
                    let _ = try await apiService.itemAPI.markItemRetracted(listId: listId, itemId: itemId)
                    await MainActor.run {
                        dispatch(ListActions.retractItemSuccess)
                    }
                } catch let _ as ListError {
                    await MainActor.run {
                        dispatch(ListActions.retractItemError(.unknown))
                    }
                } catch {
                    await MainActor.run {
                        dispatch(ListActions.retractItemError(.unknown))
                    }
                }
            }
        case .retractItemSuccess:
            dispatch(ListActions.loadHomeFeed)
        case .retractItemError(_):
            break
        case .deleteItem(itemId: let itemId, listId: let listId):
            Task {
                do {
                    let _ = try await apiService.itemAPI.deleteItem(listId: listId, itemId: itemId)
                    await MainActor.run {
                        dispatch(ListActions.deleteItemSuccess)
                    }
                } catch let _ as ListError {
                    await MainActor.run {
                        dispatch(ListActions.deleteItemError(.unknown))
                    }
                } catch {
                    await MainActor.run {
                        dispatch(ListActions.deleteItemError(.unknown))
                    }
                }
            }
        case .deleteItemSuccess:
            dispatch(ListActions.loadHomeFeed)
            
        case .deleteItemError(_):
            break
            
        case .updateItem(itemDetails: var newItemDetails, listInContext: let listInContext):
            Task {
                do {
                    let imageUrl = await ImageUtiliy.fetchImagePathForItem(urlString: newItemDetails.itemLink)
                    newItemDetails.itemImageUrl = imageUrl
                    let _ = try await apiService.itemAPI.updateItem(listInContext: listInContext, updatedItem: newItemDetails)
                    dispatch(ListActions.updateItemSuccess)
                } catch let _ as ListError {
                    await MainActor.run {
                        dispatch(ListActions.updateItemError(.unknown))
                    }
                } catch {
                    await MainActor.run {
                        dispatch(ListActions.updateItemError(.unknown))
                    }
                }
            }
            
        case .updateItemSuccess:
            dispatch(ListActions.loadHomeFeed)
        case .updateItemError:
            break
        case .updateItemFlowComplete:
            break
        case .listErrorsCleared:
            break
        case .loadActivity:
            break
        case .activityLoaded:
            break
        case .activityError(_):
            break
        case .loadHomeFeed:
            Task {
                do {
                    let homeFeedResponse = try await apiService.listAPI.getHomeFeed()
                    await MainActor.run {
                        dispatch(ListActions.homeFeedLoaded(homeFeedResponse.appData))
                        dispatch(ActivityActions.homeFeedLoaded(homeFeedResponse.appData))
                        dispatch(UserActions.homeFeedLoaded(homeFeedResponse.appData))
                    }
                } catch {
                    await MainActor.run {
                        dispatch(UserActions.logout)
                    }
                }
            }
        case .homeFeedLoaded(_):
            break
        }
    }
}
