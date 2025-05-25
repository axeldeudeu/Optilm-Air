// lib/pages/preferences_page.dart

import 'package:flutter/material.dart';
import '../models/recommendation_model.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({Key? key}) : super(key: key);

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  late UserPreferences _preferences;
  bool _isLoading = true;
  
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      _emailController.text = _preferences.email ?? '';
      _phoneController.text = _preferences.phoneNumber ?? '';
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des préférences: $e');
      _preferences = UserPreferences();
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    _preferences.email = _emailController.text.isNotEmpty ? _emailController.text : null;
    _preferences.phoneNumber = _phoneController.text.isNotEmpty ? _phoneController.text : null;
    
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Préférences sauvegardées avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sauvegarde: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Préférences de notification'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF121212), const Color(0xFF0A1929)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0088FF)),
                ),
              )
            : _buildPreferencesForm(),
      ),
    );
  }

  Widget _buildPreferencesForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 80), // Espace pour l'AppBar
          
          _buildSection(
            icon: Icons.notifications,
            title: 'Notifications',
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Activer les notifications', 
                    style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                    'Recevez des alertes sur la qualité de l\'air',
                    style: TextStyle(color: Colors.white70),
                  ),
                  value: _preferences.notificationsEnabled,
                  activeColor: const Color(0xFF0088FF),
                  onChanged: (value) {
                    setState(() {
                      _preferences.notificationsEnabled = value;
                    });
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          if (_preferences.notificationsEnabled) ...[
            _buildSection(
              icon: Icons.group,
              title: 'Groupes à risque',
              child: Column(
                children: [
                  _buildCheckboxListTile(
                    title: 'Général',
                    value: _preferences.selectedRiskGroups.contains(RiskGroup.general),
                    onChanged: (value) {
                      setState(() {
                        if (value!) {
                          _preferences.selectedRiskGroups.add(RiskGroup.general);
                        } else {
                          _preferences.selectedRiskGroups.remove(RiskGroup.general);
                        }
                      });
                    },
                  ),
                  _buildCheckboxListTile(
                    title: 'Asthmatique',
                    value: _preferences.selectedRiskGroups.contains(RiskGroup.asthmatic),
                    onChanged: (value) {
                      setState(() {
                        if (value!) {
                          _preferences.selectedRiskGroups.add(RiskGroup.asthmatic);
                        } else {
                          _preferences.selectedRiskGroups.remove(RiskGroup.asthmatic);
                        }
                      });
                    },
                  ),
                  _buildCheckboxListTile(
                    title: 'Personnes âgées',
                    value: _preferences.selectedRiskGroups.contains(RiskGroup.elderly),
                    onChanged: (value) {
                      setState(() {
                        if (value!) {
                          _preferences.selectedRiskGroups.add(RiskGroup.elderly);
                        } else {
                          _preferences.selectedRiskGroups.remove(RiskGroup.elderly);
                        }
                      });
                    },
                  ),
                  _buildCheckboxListTile(
                    title: 'Enfants',
                    value: _preferences.selectedRiskGroups.contains(RiskGroup.children),
                    onChanged: (value) {
                      setState(() {
                        if (value!) {
                          _preferences.selectedRiskGroups.add(RiskGroup.children);
                        } else {
                          _preferences.selectedRiskGroups.remove(RiskGroup.children);
                        }
                      });
                    },
                  ),
                  _buildCheckboxListTile(
                    title: 'Problèmes cardiaques',
                    value: _preferences.selectedRiskGroups.contains(RiskGroup.heartCondition),
                    onChanged: (value) {
                      setState(() {
                        if (value!) {
                          _preferences.selectedRiskGroups.add(RiskGroup.heartCondition);
                        } else {
                          _preferences.selectedRiskGroups.remove(RiskGroup.heartCondition);
                        }
                      });
                    },
                  ),
                  _buildCheckboxListTile(
                    title: 'Femmes enceintes',
                    value: _preferences.selectedRiskGroups.contains(RiskGroup.pregnant),
                    onChanged: (value) {
                      setState(() {
                        if (value!) {
                          _preferences.selectedRiskGroups.add(RiskGroup.pregnant);
                        } else {
                          _preferences.selectedRiskGroups.remove(RiskGroup.pregnant);
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            _buildSection(
              icon: Icons.send,
              title: 'Méthodes de notification',
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Notifications push', 
                      style: TextStyle(color: Colors.white)),
                    value: _preferences.pushNotifications,
                    activeColor: const Color(0xFF0088FF),
                    onChanged: (value) {
                      setState(() {
                        _preferences.pushNotifications = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Notifications par email', 
                      style: TextStyle(color: Colors.white)),
                    value: _preferences.emailNotifications,
                    activeColor: const Color(0xFF0088FF),
                    onChanged: (value) {
                      setState(() {
                        _preferences.emailNotifications = value;
                      });
                    },
                  ),
                  if (_preferences.emailNotifications)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: TextField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Adresse email',
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white38),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF0088FF)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  SwitchListTile(
                    title: const Text('Notifications par SMS', 
                      style: TextStyle(color: Colors.white)),
                    value: _preferences.smsNotifications,
                    activeColor: const Color(0xFF0088FF),
                    onChanged: (value) {
                      setState(() {
                        _preferences.smsNotifications = value;
                      });
                    },
                  ),
                  if (_preferences.smsNotifications)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: TextField(
                        controller: _phoneController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Numéro de téléphone',
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white38),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFF0088FF)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          Center(
            child: ElevatedButton(
              onPressed: _savePreferences,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0088FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Sauvegarder'),
            ),
          ),
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }
  
  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF162033),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF00E5FF), size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          child,
        ],
      ),
    );
  }
  
  Widget _buildCheckboxListTile({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      value: value,
      activeColor: const Color(0xFF0088FF),
      checkColor: Colors.white,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}