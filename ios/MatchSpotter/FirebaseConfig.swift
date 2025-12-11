//
//  FirebaseConfig.swift
//  MatchSpotter
//
//  Created by Claude
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

/// Firebase設定クラス
class FirebaseConfig {
    static let shared = FirebaseConfig()

    private init() {}

    /// Firebaseを初期化
    func configure() {
        FirebaseApp.configure()
    }

    /// Firestoreのインスタンスを取得
    var db: Firestore {
        return Firestore.firestore()
    }

    /// Authのインスタンスを取得
    var auth: Auth {
        return Auth.auth()
    }
}
