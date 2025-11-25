//
//  MockData.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import Foundation

struct MockData {
    static let loggedInUser = AuthResponse(userInfo: AuthModel(userId: "4b5954c3-bd3d-11ef-b8e2-0242ac120002",
                                                               firstName: "John",
                                                               lastName: "Doe",
                                                               pcr: false))
    
    static let stats = PurchaseStatsResponse(purchaseStats: [PurchaseStat()])
    
    static let appData = RawData.rawDataTransformer(source: RawData.appDataJSON, type: AppData.self)
    static let appDataResponse = AppDataResponse(appData: appData)
    
    
    
    static let updateResponse = UpdateInfoModelResponse(version: UpdateInfoModel(availableVersion: "1.3",
                                                                                 downloadUri: "https://www.foo.com"))
    
    static let sampleListDetail = ListSummary(id: "123",
                                              name: "Sample Christmas List",
                                              listTheme: "Sample theme",
                                              ownerInfo: LWUserModel(id: "123",
                                                                     firstName: "John",
                                                                     lastName: "Doe"),
                                              status: .active,
                                              creationDate: "2025-12-05",
                                              lastUpdateDate: "2025-12-05",
                                              totalItems: 12,
                                              purchasedItems: 8,
                                              members: [],
                                              items: [ItemDetails(id: "234",
                                                                  name: "Sample Item",
                                                                  description: "Sample Item Description",
                                                                  link: "https://www.apple.com/shop/buy-airpods/airpods-pro-3",
                                                                  price: 199.00,
                                                                  quantity: 1,
                                                                  imageUrl: "https://store.storeimages.cdn-apple.com/1/as-images.apple.com/is/airpods-pro-3-hero-select-202509?wid=1200&hei=630&fmt=jpeg&qlt=95&.v=1758077264484",
                                                                  createdBy: "123",
                                                                  creationDate: "2025-12-05",
                                                                  lastEditDate: "2025-12-05",
                                                                  offListItem: false,
                                                                  priority: .medium,
                                                                  retractablePurchase: false,
                                                                  purchaseState: .available,
                                                                  quantityPurchased: 0,
                                                                  deleteAllowed: false,
                                                                  editAllowed: false,
                                                                  canViewMetadata: true),
                                                      ItemDetails(id: "345",
                                                                          name: "Sample Item 2",
                                                                          description: "Sample Item Description",
                                                                          link: "https://www.apple.com/shop/buy-airpods/airpods-pro-3",
                                                                          price: 199.00,
                                                                          quantity: 1,
                                                                          imageUrl: "https://store.storeimages.cdn-apple.com/1/as-images.apple.com/is/airpods-pro-3-hero-select-202509?wid=1200&hei=630&fmt=jpeg&qlt=95&.v=1758077264484",
                                                                          createdBy: "123",
                                                                          creationDate: "2025-12-05",
                                                                          lastEditDate: "2025-12-05",
                                                                          offListItem: false,
                                                                          priority: .medium,
                                                                          retractablePurchase: false,
                                                                          purchaseState: .available,
                                                                          quantityPurchased: 0,
                                                                          deleteAllowed: false,
                                                                          editAllowed: false,
                                                                          canViewMetadata: true)
                                              ], canViewMetadata: true)
    
    static let sampleItemDetail = ItemDetails(id: "123",
                                              name: "AirPods Pro 3",
                                              description: "White, not personalized",
                                              link: "https://www.apple.com/shop/buy-airpods/airpods-pro-3",
                                              price: 199.00,
                                              quantity: 1,
                                              imageUrl: "https://store.storeimages.cdn-apple.com/1/as-images.apple.com/is/airpods-pro-3-hero-select-202509?wid=1200&hei=630&fmt=jpeg&qlt=95&.v=1758077264484",
                                              createdBy: "123",
                                              creationDate: "2025-10-20",
                                              lastEditDate: "2025-10-20",
                                              offListItem: false,
                                              priority: .high,
                                              retractablePurchase: false,
                                              purchaseState: .available,
                                              quantityPurchased: 0,
                                              deleteAllowed: false,
                                              editAllowed: false,
                                              canViewMetadata: true)
    
    static let itemPurchase = ItemPurchaseResponse(purchaseInfo: PurchaseInfo(id: "1234"))
    static let addItem = AddItemResponse(itemInfo: AddItemInfo(itemId: "1234"))
    static let addList = AddListResponse(listInfo: AddListInfo(listId: "12345"))
    static let updatePassword = ChangePasswordResponse(passwordInfo: ChangePasswordInfo(userId: "1234"))
    static let activityFeed = [ActivityItem(id: "123",
                                            type: .itemRemoval,
                                            owner: LWUserModel(id: "234",
                                                               firstName: "John",
                                                               lastName: "Doe"),
                                            date: "2025-12-02",
                                            userName: "Nikki",
                                            itemName: "Nursing Pads",
                                            listName: "Nikki's 2025 Christmas List"),
                               ActivityItem(id: "345",
                                            type: .purchase,
                                            owner: LWUserModel(id: "456",
                                                               firstName: "John",
                                                               lastName: "Doe"),
                                            date: "2025-12-02",
                                            userName: "Nikki",
                                            itemName: "Lego Hogwarts Castle",
                                            listName: "Graham's 2025 Christmas List"),
                               ActivityItem(id: "567",
                                            type: .itemAddition,
                                            owner: LWUserModel(id: "678",
                                                               firstName: "John",
                                                               lastName: "Doe"),
                                            date: "2025-12-02",
                                            userName: "Melanie",
                                            itemName: "Lego Diagon Alley",
                                            listName: "Melanie's 2025 Christmas List"),
                               ActivityItem(id: "789",
                                            type: .listAddition,
                                            owner: LWUserModel(id: "890",
                                                               firstName: "John",
                                                               lastName: "Doe"),
                                            date: "2025-12-02",
                                            userName: "Dennis",
                                            itemName: "",
                                            listName: "Dennis' List"),
                               ActivityItem(id: "098",
                                            type: .retraction,
                                            owner: LWUserModel(id: "987",
                                                               firstName: "John",
                                                               lastName: "Doe"),
                                            date: "2025-12-02",
                                            userName: "David",
                                            itemName: "Bill O'Reilly Book",
                                            listName: "Dennis' List"),
                               ActivityItem(id: "134",
                                            type: .listRemoval,
                                            owner: LWUserModel(id: "135",
                                                               firstName: "John",
                                                               lastName: "Doe"),
                                            date: "2025-12-02",
                                            userName: "Nancy",
                                            itemName: "",
                                            listName: "Nancy Typo List")
    ]
    static let updateProfile = UpdateProfileResponse(updateInfo: UpdateProfileInfo(userId: "!2345"))
    static let userMetadata = UserMetadataResponse(userMetadata: UserMetadata(userId: "foo@gmail.com",
                                                                              email: "foo@gmail.com",
                                                                              firstName: "John",
                                                                              lastName: "Doe",
                                                                              creationDate: "2024-12-20T19:48:34.000Z",
                                                                              lastLogInDate: "2025-10-15T01:19:33.000Z",
                                                                              lastLogInLocation: generateRandomIP(),
                                                                              lastPasswordChange: "2025-10-15T01:19:33.000Z"))
}

fileprivate func generateRandomIP() -> String {
    let firstOctet = Int.random(in: 1...254)
    let secondOctet = Int.random(in: 0...255)
    let thirdOctet = Int.random(in: 0...255)
    return "\(firstOctet).\(secondOctet).\(thirdOctet)"
    
}


fileprivate struct RawData {
    
    static func rawDataTransformer<T: Decodable>(source: String, type: T.Type) -> T {
        guard let jsonData = source.data(using: .utf8) else {
            fatalError("MockData.RawData: Failed to encode source string as UTF-8.")
        }
        do {
            return try JSONDecoder().decode(T.self, from: jsonData)
        } catch {
            fatalError("MockData.RawData: Failed to decode JSON into \(T.self): \(error)")
        }
    }
    
    
    static let appDataJSON =
    """
    {
      "userMetadata": {
        "userId": "4b5954c3-bd3d-11ef-b8e2-0242ac120002",
        "email": "nlalberta@gmail.com",
        "firstName": "Nicole",
        "lastName": "Canzonetta",
        "creationDate": "2024-12-20T19:48:34.000Z",
        "lastLogInDate": "2025-10-15T01:19:33.000Z",
        "lastLogInLocation": "10.1.20.179",
        "lastPasswordChange": "2024-12-20T19:48:34.000Z"
      },
      "listOverviews": [
        {
          "listId": "54d9f46f-9428-11f0-8b49-0242ac120002",
          "name": "New Group Name",
          "status": "active",
          "creationDate": "2025-09-18T04:42:31.000Z",
          "lastUpdateDate": "2025-09-18T04:55:38.000Z",
          "listTheme": "Sample list theme for things Nikki likes.",
          "totalItems": 9,
          "purchasedItems": 2,
          "ownerInfo": {
            "userId": "4b5954c3-bd3d-11ef-b8e2-0242ac120002",
            "firstName": "Nicole",
            "lastName": "Canzonetta"
          },
          "members": [
            {
              "userId": "4b58e61a-bd3d-11ef-b8e2-0242ac120002",
              "firstName": "Graham",
              "lastName": "Alberta"
            },
            {
              "userId": "4b5954c3-bd3d-11ef-b8e2-0242ac120002",
              "firstName": "Nicole",
              "lastName": "Canzonetta"
            }
          ],
          "items": [
            {
              "itemId": "844cec30-94eb-11f0-8b49-0242ac120002",
              "name": "Test Name 12",
              "description": "Test Description",
              "link": "http://foo.com",
              "price": 100,
              "quantity": 1,
              "imageUrl": "",
              "createdBy": "4b58e61a-bd3d-11ef-b8e2-0242ac120002",
              "creationDate": "2025-09-18 23:59:45",
              "lastEditDate": "2025-09-18 23:59:45",
              "offListItem": false,
              "priority": 0,
              "retractablePurchase": false,
              "purchaseState": "available",
              "purchasesAllowed": true,
              "quantityPurchased": 0,
              "deleteAllowed": false,
              "editAllowed": false,
              "canViewMetadata": true
            },
            {
              "itemId": "9e49ecea-94eb-11f0-8b49-0242ac120002",
              "name": "Test Name 12",
              "description": "Test Description",
              "link": "http://foo.com",
              "price": 100,
              "quantity": 1,
              "imageUrl": "",
              "createdBy": "4b58e61a-bd3d-11ef-b8e2-0242ac120002",
              "creationDate": "2025-09-19 00:00:28",
              "lastEditDate": "2025-09-19 00:00:28",
              "offListItem": false,
              "priority": 0,
              "retractablePurchase": false,
              "purchaseState": "available",
              "purchasesAllowed": true,
              "quantityPurchased": 0,
              "deleteAllowed": false,
              "editAllowed": false,
              "canViewMetadata": true
            },
            {
              "itemId": "ab943baa-94eb-11f0-8b49-0242ac120002",
              "name": "Test Name 12",
              "description": "Test Description",
              "link": "http://foo.com",
              "price": 100,
              "quantity": 1,
              "imageUrl": "",
              "createdBy": "4b58e61a-bd3d-11ef-b8e2-0242ac120002",
              "creationDate": "2025-09-19 00:00:50",
              "lastEditDate": "2025-09-19 00:00:50",
              "offListItem": false,
              "priority": 1,
              "retractablePurchase": false,
              "purchaseState": "available",
              "purchasesAllowed": true,
              "quantityPurchased": 0,
              "deleteAllowed": false,
              "editAllowed": false,
              "canViewMetadata": true
            },
            {
              "itemId": "f2192695-958d-11f0-8b49-0242ac120002",
              "name": "Sample Item",
              "description": "Sample Description",
              "link": "Sample Link",
              "price": 2,
              "quantity": 1,
              "imageUrl": "",
              "createdBy": "4b58e61a-bd3d-11ef-b8e2-0242ac120002",
              "creationDate": "2025-09-19 19:22:29",
              "lastEditDate": "2025-09-19 19:22:29",
              "offListItem": true,
              "priority": 3,
              "retractablePurchase": false,
              "purchaseState": "unavailable",
              "purchasesAllowed": false,
              "quantityPurchased": 1,
              "deleteAllowed": false,
              "editAllowed": false,
              "canViewMetadata": true
            },
            {
              "itemId": "af896808-9590-11f0-8b49-0242ac120002",
              "name": "Renamed Item Name",
              "description": "Renamed Description",
              "link": "http://bar.com",
              "price": 999,
              "quantity": 5,
              "imageUrl": "",
              "createdBy": "4b5954c3-bd3d-11ef-b8e2-0242ac120002",
              "creationDate": "2025-09-19 19:42:06",
              "lastEditDate": "2025-09-19 20:06:16",
              "offListItem": true,
              "priority": 2,
              "retractablePurchase": true,
              "purchaseState": "partial",
              "purchasesAllowed": false,
              "quantityPurchased": 1,
              "deleteAllowed": true,
              "editAllowed": true,
              "canViewMetadata": true
            }
          ],
          "canViewMetadata": true
        },
        {
          "listId": "905c4fe7-bd42-11ef-b8e2-0242ac120002",
          "name": "Dennis' Christmas List 2024",
          "status": "active",
          "creationDate": "2024-12-20T20:26:18.000Z",
          "lastUpdateDate": "2024-12-20T20:26:18.000Z",
          "listTheme": "Grumpy old man stuff.",
          "totalItems": 10,
          "purchasedItems": 10,
          "ownerInfo": {
              "userId": "4b5a1fc3-bd3d-11ef-b8e2-0242ac120002",
              "firstName": "Dennis",
              "lastName": "Alberta"
            },
          "members": [
            {
              "userId": "b1015091-bc88-11ef-b8e2-0242ac120002",
              "firstName": "Brian",
              "lastName": "Alberta"
            },
            {
              "userId": "7f7c98b8-bcf8-11ef-b8e2-0242ac120002",
              "firstName": "Melanie",
              "lastName": "Alberta"
            },
            {
              "userId": "4b58e61a-bd3d-11ef-b8e2-0242ac120002",
              "firstName": "Graham",
              "lastName": "Alberta"
            },
            {
              "userId": "4b5954c3-bd3d-11ef-b8e2-0242ac120002",
              "firstName": "Nicole",
              "lastName": "Canzonetta"
            },
            {
              "userId": "4b59cf4c-bd3d-11ef-b8e2-0242ac120002",
              "firstName": "Nancy",
              "lastName": "Krepczynski"
            },
            {
              "userId": "4b5a1fc3-bd3d-11ef-b8e2-0242ac120002",
              "firstName": "Dennis",
              "lastName": "Alberta"
            },
            {
              "userId": "4b5a61d2-bd3d-11ef-b8e2-0242ac120002",
              "firstName": "Bill",
              "lastName": "Krepczynski"
            },
            {
              "userId": "4b5aa121-bd3d-11ef-b8e2-0242ac120002",
              "firstName": "Gayle",
              "lastName": "Alberta"
            },
            {
              "userId": "4b5b0b38-bd3d-11ef-b8e2-0242ac120002",
              "firstName": "David",
              "lastName": "Canzonetta"
            },
            {
              "userId": "4b5ba242-bd3d-11ef-b8e2-0242ac120002",
              "firstName": "Owen",
              "lastName": "Alberta"
            }
          ],
          "items": [
            {
              "itemId": "329beab5-bd4b-11ef-b8e2-0242ac120002",
              "name": "Will Robie Series Complete 5 Books Collection Set by David Baldacci (The Innocent, The Hit, The Target, The Guilty & End Game)",
              "description": "(The Innocent, The Hit, The Target, The Guilty & End Game)",
              "link": "https://www.amazon.com/gp/product/1529067464/ref=ox_sc_saved_title_2?smid=AEY8Y1M2ZEQUD&psc=1",
              "price": 42.99,
              "quantity": \(Int.random(in: 1...10)),
              "imageUrl": "https://m.media-amazon.com/images/I/81piZ0asC4L.jpg_BO30,255,255,255_UF900,850_SR1910,1000,0,C_QL100_.jpg",
              "createdBy": "4b5a1fc3-bd3d-11ef-b8e2-0242ac120002",
              "creationDate": "2024-12-20 16:28:06",
              "lastEditDate": "2024-12-20 16:28:06",
              "offListItem": false,
              "priority": 1,
              "retractablePurchase": false,
              "purchaseState": "unavailable",
              "purchasesAllowed": false,
              "quantityPurchased": 1,
              "deleteAllowed": true,
              "editAllowed": true,
              "canViewMetadata": true
            },
            {
              "itemId": "dfc5dc8c-bd4b-11ef-b8e2-0242ac120002",
              "name": "Skechers Slip-ins RF: Edgeride - Raygo",
              "description": "10.5; Medium; White/Gray",
              "link": "https://www.skechers.com/skechers-slip-ins-rf-edgeride---raygo/232932_WGY.html",
              "price": 85,
              "quantity": 1,
              "imageUrl": "https://images.skechers.com/image;width=auto%2Cformat=auto/232932_WGY_HERO_LG",
              "createdBy": "4b5a1fc3-bd3d-11ef-b8e2-0242ac120002",
              "creationDate": "2024-12-20 16:32:56",
              "lastEditDate": "2024-12-20 16:32:56",
              "offListItem": false,
              "priority": null,
              "retractablePurchase": false,
              "purchaseState": "available",
              "purchasesAllowed": false,
              "quantityPurchased": 1,
              "deleteAllowed": true,
              "editAllowed": true,
              "canViewMetadata": true
            },
            {
              "itemId": "e5dbd0dd-bd4c-11ef-b8e2-0242ac120002",
              "name": "Bonhoeffer: Pastor, Martyr, Prophet, Spy",
              "description": "Paperback",
              "link": "https://www.amazon.com/gp/product/1400224640/ref=ox_sc_saved_title_1?smid=ATVPDKIKX0DER&psc=1",
              "price": 17.74,
              "quantity": 1,
              "imageUrl": "https://m.media-amazon.com/images/I/81uS9qE7AvL.jpg_BO30,255,255,255_UF900,850_SR1910,1000,0,C_QL100_.jpg",
              "createdBy": "4b5a1fc3-bd3d-11ef-b8e2-0242ac120002",
              "creationDate": "2024-12-20 16:40:16",
              "lastEditDate": "2024-12-20 16:40:16",
              "offListItem": false,
              "priority": 3,
              "retractablePurchase": false,
              "purchaseState": "partial",
              "purchasesAllowed": false,
              "quantityPurchased": 1,
              "deleteAllowed": false,
              "editAllowed": true,
              "canViewMetadata": true
            },
            {
              "itemId": "e5dc8120-bd4c-11ef-b8e2-0242ac120002",
              "name": "Ohio State Buckeyes Colosseum Too Cool For School Long Sleeve Polo - Scarlet",
              "description": "Scarlet; XL",
              "link": "https://www.fanatics.com/college/ohio-state-buckeyes/ohio-state-buckeyes-colosseum-too-cool-for-school-long-sleeve-polo-scarlet/o-16+t-79777702+p-68668090268305+z-9-633272166?_ref=p-PDP:m-RV:pi-PDP_RECOMMENDATIONS_1:i-r0c2:po-2",
              "price": 49.99,
              "quantity": 1,
              "imageUrl": "https://fanatics.frgimages.com/ohio-state-buckeyes/mens-colosseum-scarlet-ohio-state-buckeyes-too-cool-for-school-long-sleeve-polo_ss5_p-202147638+u-gjeok1wmvt5p8jf1zc5b+v-br6rugwygbzsa6edj4xw.jpg?_hv=2",
              "createdBy": "4b5a1fc3-bd3d-11ef-b8e2-0242ac120002",
              "creationDate": "2024-12-20 16:40:16",
              "lastEditDate": "2024-12-20 16:40:16",
              "offListItem": false,
              "priority": 0,
              "retractablePurchase": false,
              "purchaseState": "purchased",
              "purchasesAllowed": false,
              "quantityPurchased": 1,
              "deleteAllowed": false,
              "editAllowed": true,
              "canViewMetadata": true
            }
          ],
          "canViewMetadata": true
        }
      ],
      "activity": [
        {
          "listName": "Nikki's 2025 Christmas List",
          "owner": {
            "firstName": "John",
            "userId": "234",
            "lastName": "Doe"
          },
          "date": "2025-12-02",
          "userName": "Nikki",
          "type": "itemRemoval",
          "id": "123",
          "itemName": "Nursing Pads"
        },
        {
          "id": "345",
          "listName": "Graham's 2025 Christmas List",
          "userName": "Nikki",
          "type": "purchase",
          "owner": {
            "lastName": "Doe",
            "userId": "456",
            "firstName": "John"
          },
          "itemName": "Lego Hogwarts Castle",
          "date": "2025-12-02"
        },
        {
          "type": "itemAddition",
          "owner": {
            "lastName": "Doe",
            "userId": "678",
            "firstName": "John"
          },
          "listName": "Melanie's 2025 Christmas List",
          "itemName": "Lego Diagon Alley",
          "id": "567",
          "date": "2025-12-02",
          "userName": "Melanie"
        },
        {
          "listName": "Dennis' List",
          "itemName": "",
          "userName": "Dennis",
          "id": "789",
          "owner": {
            "lastName": "Doe",
            "userId": "890",
            "firstName": "John"
          },
          "date": "2025-12-02",
          "type": "listAddition"
        },
        {
          "id": "098",
          "listName": "Dennis' List",
          "date": "2025-12-02",
          "itemName": "Bill O'Reilly Book",
          "type": "retraction",
          "userName": "David",
          "owner": {
            "lastName": "Doe",
            "userId": "987",
            "firstName": "John"
          }
        },
        {
          "date": "2025-12-02",
          "type": "listRemoval",
          "owner": {
            "lastName": "Doe",
            "userId": "135",
            "firstName": "John"
          },
          "id": "134",
          "userName": "Nancy",
          "itemName": "",
          "listName": "Nancy Typo List"
        }
      ]
    }
    """
}
