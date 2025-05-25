// lib/models/recommendation_model.dart

import 'package:flutter/material.dart';

enum RiskGroup {
  general,
  asthmatic,
  elderly,
  children,
  heartCondition,
  pregnant,
}

class Recommendation {
  final String message;
  final String actionTitle;
  final String actionDescription;
  final IconData icon;
  final Color color;

  Recommendation({
    required this.message,
    required this.actionTitle,
    required this.actionDescription,
    required this.icon,
    required this.color,
  });
}

class RecommendationService {
  static List<Recommendation> getRecommendationsForAQI(double aqi, List<RiskGroup> riskGroups) {
    List<Recommendation> recommendations = [];

    // Recommandations générales basées sur l'AQI
    if (aqi <= 100) {
      // Bonne qualité de l'air
      recommendations.add(
        Recommendation(
          message: "La qualité de l'air est bonne.",
          actionTitle: "Activités extérieures",
          actionDescription: "C'est un excellent moment pour profiter d'activités en plein air.",
          icon: Icons.directions_run,
          color: Colors.green,
        ),
      );
    } else if (aqi <= 200) {
      // Qualité modérée
      recommendations.add(
        Recommendation(
          message: "La qualité de l'air est acceptable.",
          actionTitle: "Activités normales",
          actionDescription: "Vous pouvez poursuivre vos activités habituelles en plein air.",
          icon: Icons.directions_walk,
          color: Colors.yellow.shade700,
        ),
      );
    } else if (aqi <= 300) {
      // Insalubre pour les personnes sensibles
      recommendations.add(
        Recommendation(
          message: "La qualité de l'air peut affecter les personnes sensibles.",
          actionTitle: "Limitation modérée",
          actionDescription: "Envisagez de réduire les activités intenses en plein air.",
          icon: Icons.access_time,
          color: Colors.orange,
        ),
      );
    } else if (aqi <= 400) {
      // Insalubre
      recommendations.add(
        Recommendation(
          message: "La qualité de l'air est insalubre.",
          actionTitle: "Réduction des activités",
          actionDescription: "Réduisez les activités prolongées en plein air, surtout si vous ressentez des symptômes.",
          icon: Icons.home,
          color: Colors.red,
        ),
      );
    } else if (aqi <= 450) {
      // Très insalubre
      recommendations.add(
        Recommendation(
          message: "La qualité de l'air est très insalubre.",
          actionTitle: "Restez à l'intérieur",
          actionDescription: "Évitez les activités en plein air. Restez à l'intérieur et fermez les fenêtres.",
          icon: Icons.do_not_touch,
          color: Colors.purple,
        ),
      );
    } else {
      // Dangereux
      recommendations.add(
        Recommendation(
          message: "La qualité de l'air est dangereuse.",
          actionTitle: "Confinement recommandé",
          actionDescription: "Restez à l'intérieur avec les fenêtres fermées et utilisez un purificateur d'air si disponible.",
          icon: Icons.warning,
          color: Colors.brown,
        ),
      );
    }

    // Recommandations spécifiques aux groupes à risque
    if (aqi > 200) {
      if (riskGroups.contains(RiskGroup.asthmatic)) {
        recommendations.add(
          Recommendation(
            message: "Attention pour les personnes asthmatiques.",
            actionTitle: "Médicaments préventifs",
            actionDescription: "Gardez votre inhalateur à portée de main et suivez votre plan de traitement.",
            icon: Icons.medication,
            color: Colors.red,
          ),
        );
      }

      if (riskGroups.contains(RiskGroup.elderly)) {
        recommendations.add(
          Recommendation(
            message: "Attention pour les personnes âgées.",
            actionTitle: "Limitation d'exposition",
            actionDescription: "Limitez le temps passé à l'extérieur et restez hydraté.",
            icon: Icons.elderly,
            color: Colors.orange,
          ),
        );
      }

      if (riskGroups.contains(RiskGroup.children)) {
        recommendations.add(
          Recommendation(
            message: "Attention pour les enfants.",
            actionTitle: "Activités intérieures",
            actionDescription: "Privilégiez les activités à l'intérieur pour les enfants.",
            icon: Icons.child_care,
            color: Colors.orange,
          ),
        );
      }

      if (riskGroups.contains(RiskGroup.heartCondition)) {
        recommendations.add(
          Recommendation(
            message: "Attention pour les personnes avec des problèmes cardiaques.",
            actionTitle: "Réduire l'effort",
            actionDescription: "Évitez les efforts physiques et surveillez vos symptômes.",
            icon: Icons.favorite,
            color: Colors.red,
          ),
        );
      }

      if (riskGroups.contains(RiskGroup.pregnant)) {
        recommendations.add(
          Recommendation(
            message: "Attention pour les femmes enceintes.",
            actionTitle: "Limiter l'exposition",
            actionDescription: "Limitez votre exposition à l'air extérieur pollué.",
            icon: Icons.pregnant_woman,
            color: Colors.orange,
          ),
        );
      }
    }

    // Recommandation de port de masque pour AQI élevé
    if (aqi >=  200) {
      recommendations.add(
        Recommendation(
          message: "Le port d'un masque est recommandé.",
          actionTitle: "Masque de protection",
          actionDescription: "Portez un masque N95 ou FFP2 si vous devez sortir pour de longues activitées.",
          icon: Icons.masks,
          color: Colors.red,
        ),
      );
    }

    return recommendations;
  }
}

class UserPreferences {
  bool notificationsEnabled = true;
  bool pushNotifications = true;
  bool emailNotifications = false;
  bool smsNotifications = false;
  Set<RiskGroup> selectedRiskGroups = {RiskGroup.general};
  String? email;
  String? phoneNumber;

  UserPreferences();
  
  UserPreferences.fromJson(Map<String, dynamic> json)
      : notificationsEnabled = json['notificationsEnabled'] ?? true,
        pushNotifications = json['pushNotifications'] ?? true,
        emailNotifications = json['emailNotifications'] ?? false,
        smsNotifications = json['smsNotifications'] ?? false,
        selectedRiskGroups = (json['selectedRiskGroups'] as List<dynamic>?)
                ?.map((e) => RiskGroup.values[e])
                .toSet() ??
            {RiskGroup.general},
        email = json['email'],
        phoneNumber = json['phoneNumber'];

  Map<String, dynamic> toJson() => {
        'notificationsEnabled': notificationsEnabled,
        'pushNotifications': pushNotifications,
        'emailNotifications': emailNotifications,
        'smsNotifications': smsNotifications,
        'selectedRiskGroups':
            selectedRiskGroups.map((e) => e.index).toList(),
        'email': email,
        'phoneNumber': phoneNumber,
      };
}

class NotificationService {
  static Future<void> sendPushNotification(String title, String body) async {
    // Dans une application réelle, cette fonction enverrait la notification
    // avec Firebase Cloud Messaging ou un service similaire
    print('Envoi de notification push: $title - $body');
    
    // Simulation de l'envoi de notification
    await Future.delayed(const Duration(seconds: 1));
    
    // Retourner avec succès
    return;
  }
  
  static Future<void> sendEmailNotification(String email, String title, String body) async {
    // Dans une application réelle, cette fonction enverrait un email
    print('Envoi d\'email à $email: $title - $body');
    
    // Simulation de l'envoi d'email
    await Future.delayed(const Duration(seconds: 1));
    
    // Retourner avec succès
    return;
  }
  
  static Future<void> sendSMSNotification(String phoneNumber, String body) async {
    // Dans une application réelle, cette fonction enverrait un SMS
    print('Envoi de SMS à $phoneNumber: $body');
    
    // Simulation de l'envoi de SMS
    await Future.delayed(const Duration(seconds: 1));
    
    // Retourner avec succès
    return;
  }

  static Future<void> sendNotificationsBasedOnPreferences(
    UserPreferences preferences,
    double aqi,
    String locationName,
  ) async {
    if (!preferences.notificationsEnabled) return;
    
    String title = 'Alerte qualité de l\'air';
    String body = _getNotificationBody(aqi, locationName, preferences.selectedRiskGroups);
    
    if (preferences.pushNotifications) {
      await sendPushNotification(title, body);
    }
    
    if (preferences.emailNotifications && preferences.email != null) {
      await sendEmailNotification(preferences.email!, title, body);
    }
    
    if (preferences.smsNotifications && preferences.phoneNumber != null) {
      await sendSMSNotification(preferences.phoneNumber!, body);
    }
  }
  
  static String _getNotificationBody(double aqi, String locationName, Set<RiskGroup> riskGroups) {
    String baseMessage = '';
    
    if (aqi <= 100) {
      baseMessage = "La qualité de l'air est très bonne à $locationName (AQI: ${aqi.toInt()}).";
    } else if (aqi <= 200) {
      baseMessage = "La qualité de l'air est bonne à $locationName (AQI: ${aqi.toInt()}).";
    } else if (aqi <= 300) {
      baseMessage = "La qualité de l'air est moyenne à $locationName (AQI: ${aqi.toInt()}).";
    } else if (aqi <= 400) {
      baseMessage = "La qualité de l'air est mauvaise à $locationName (AQI: ${aqi.toInt()}).";
    } else if (aqi <= 500) {
      baseMessage = "La qualité de l'air est insalubre à $locationName (AQI: ${aqi.toInt()}).";
    } else {
      baseMessage = "La qualité de l'air est extrêmement dangereuse à $locationName (AQI: ${aqi.toInt()}).";
    }
    
    // Ajouter des conseils spécifiques pour les groupes à risque si l'AQI est élevé
    String additionalAdvice = '';
    if (aqi > 100) {
      if (riskGroups.contains(RiskGroup.asthmatic)) {
        additionalAdvice += " Les asthmatiques devraient garder leur inhalateur à portée de main.";
      }
      if (riskGroups.contains(RiskGroup.children) || riskGroups.contains(RiskGroup.elderly)) {
        additionalAdvice += " Les enfants et personnes âgées devraient limiter les activités extérieures.";
      }
      if (aqi > 400) {
        additionalAdvice += " Portez un masque si vous devez sortir.";
      }
    }
    
    return baseMessage + additionalAdvice;
  }
}