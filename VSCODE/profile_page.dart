import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// Couleurs OptimAir (inchangées)
const Color primaryColor = Color(0xFF0088FF);
const Color secondaryColor = Color(0xFF00D2FF);
const Color accentColor = Color(0xFF00E5FF);
const Color darkColor = Color(0xFF121212);
const Color backgroundColor = Color(0xFF0A1929);
const Color cardColor = Color(0xFF162033);

final darkGradient = LinearGradient(
  colors: [darkColor, backgroundColor],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

class ProfilePage extends StatefulWidget {
  final String? userId;
  
  const ProfilePage({Key? key, this.userId}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  
  // Contrôleurs pour tous les champs
  final _nameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();        // NOUVEAU
  final _confirmPasswordController = TextEditingController(); // NOUVEAU
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  
  bool _notificationsEnabled = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isProfileSaved = false;
  bool _isPremiumUser = false; // NOUVEAU : Statut premium
  
  File? _imageFile;
  String? _imagePathInPrefs;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String get currentUserId => widget.userId ?? 'user_${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _firstNameController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        
        setState(() {
          _nameController.text = userData['nom'] ?? '';
          _firstNameController.text = userData['prenom'] ?? '';
          _nicknameController.text = userData['surnom'] ?? '';
          _emailController.text = userData['email'] ?? '';
          _phoneController.text = userData['telephone'] ?? '';
          _cityController.text = userData['ville'] ?? '';
          _notificationsEnabled = userData['notifications_enabled'] ?? true;
          _isPremiumUser = userData['is_premium'] ?? false;
          _imagePathInPrefs = userData['photo_profil_path'];
          _isProfileSaved = true;
          
          if (_imagePathInPrefs != null && _imagePathInPrefs!.isNotEmpty) {
            final file = File(_imagePathInPrefs!);
            if (file.existsSync()) {
              _imageFile = file;
            }
          }
        });
      } else {
        // Créer le document avec set() au lieu d'essayer update() plus tard
        await _firestore.collection('users').doc(currentUserId).set({
          'nom': '',
          'prenom': '',
          'surnom': '',
          'email': '',
          'telephone': '',
          'ville': '',
          'notifications_enabled': true,
          'is_premium': false,
          'cree_le': FieldValue.serverTimestamp(),
        });
        
        print('✅ Document utilisateur créé pour ID: $currentUserId');
      }
    } catch (e) {
      print("Erreur lors du chargement des données: $e");
      _showErrorSnackBar('Erreur lors du chargement du profil: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print("Erreur lors de la sélection de l'image: $e");
      _showErrorSnackBar('Erreur lors de la sélection de l\'image');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _saveUserData() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        Map<String, dynamic> userData = {
          'nom': _nameController.text,
          'prenom': _firstNameController.text,
          'surnom': _nicknameController.text,
          'email': _emailController.text,
          'telephone': _phoneController.text,
          'ville': _cityController.text,
          'notifications_enabled': _notificationsEnabled,
          'is_premium': _isPremiumUser, // NOUVEAU
          'derniere_mise_a_jour': FieldValue.serverTimestamp(),
        };

        if (_imageFile != null) {
          userData['photo_profil_path'] = _imageFile!.path;
        }

        // Note: Les mots de passe ne sont PAS sauvegardés en clair dans Firestore
        // Ils seraient normalement hashés ou gérés par Firebase Auth
        if (_passwordController.text.isNotEmpty) {
          print('Mot de passe défini (non sauvegardé en clair pour sécurité)');
        }
        
        // Utiliser set avec merge: true pour créer ou mettre à jour
        await _firestore
            .collection('users')
            .doc(currentUserId)
            .set(userData, SetOptions(merge: true));
        
        if (mounted) {
          _showSaveConfirmationDialog();
          setState(() {
            _isProfileSaved = true;
          });
        }
      } catch (e) {
        print("Erreur lors de la sauvegarde des données: $e");
        _showErrorSnackBar('Erreur lors de la sauvegarde: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _togglePremiumStatus() {
    setState(() {
      _isPremiumUser = !_isPremiumUser;
    });
    
    // Afficher un message de confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isPremiumUser 
            ? '🎉 Optim\'Air+ activé !' 
            : 'Optim\'Air+ désactivé',
        ),
        backgroundColor: _isPremiumUser ? Colors.green : Colors.orange,
      ),
    );
  }

  void _showSaveConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: primaryColor),
              SizedBox(width: 10),
              Text(
                'Profil mis à jour',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Text(
            'Vos informations de profil ont été mises à jour avec succès.\n\n'
            'Statut: ${_isPremiumUser ? "Optim'Air+ Premium 🌟" : "Version gratuite"}',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: Text(
                'OK',
                style: TextStyle(color: accentColor),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Mon Profil'),
        actions: [
          // Badge de statut premium dans l'AppBar
          Container(
            margin: EdgeInsets.only(right: 16),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isPremiumUser ? Colors.amber : Colors.grey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _isPremiumUser ? 'PREMIUM' : 'GRATUIT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: darkGradient,
        ),
        child: _isLoading 
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: kToolbarHeight + 20),
                    
                    // Avatar avec badge premium en haut à gauche
                    Center(
                      child: Stack(
                        children: [
                          // Avatar principal
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  _isPremiumUser ? Colors.amber : primaryColor,
                                  _isPremiumUser ? Colors.orange : secondaryColor,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: _imageFile != null
                                ? CircleAvatar(
                                    radius: 60,
                                    backgroundColor: backgroundColor,
                                    backgroundImage: FileImage(_imageFile!),
                                  )
                                : CircleAvatar(
                                    radius: 60,
                                    backgroundColor: backgroundColor,
                                    child: Icon(
                                      Icons.person,
                                      size: 60,
                                      color: _isPremiumUser ? Colors.amber : primaryColor,
                                    ),
                                  ),
                          ),
                          
                          // NOUVEAU : Badge Optim'Air+ en haut à gauche
                          Positioned(
                            top: 0,
                            left: 0,
                            child: GestureDetector(
                              onTap: _togglePremiumStatus,
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _isPremiumUser ? Colors.green : Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _isPremiumUser ? Icons.star : Icons.star_border,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          
                          // Bouton caméra (en bas à droite)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Affichage du surnom et nom/prénom
                    if (_isProfileSaved && _nicknameController.text.isNotEmpty) ...[
                      SizedBox(height: 15),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isPremiumUser) ...[
                              Icon(Icons.star, color: Colors.amber, size: 20),
                              SizedBox(width: 5),
                            ],
                            Text(
                              _nicknameController.text,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_isPremiumUser) ...[
                              SizedBox(width: 5),
                              Text(
                                'PLUS',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 5),
                      Center(
                        child: Text(
                          "${_firstNameController.text} ${_nameController.text}",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                    
                    SizedBox(height: 30),
                    
                    // CHAMPS DANS L'ORDRE DEMANDÉ
                    
                    // 1. Nom
                    _buildTextField(
                      controller: _nameController,
                      label: 'Nom',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre nom';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // 2. Prénom
                    _buildTextField(
                      controller: _firstNameController,
                      label: 'Prénom',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre prénom';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // 3. Surnom
                    _buildTextField(
                      controller: _nicknameController,
                      label: 'Surnom',
                      icon: Icons.face,
                      validator: null,
                    ),
                    
                    SizedBox(height: 16),
                    
                    // 4. NOUVEAU : Mot de passe
                    _buildPasswordField(
                      controller: _passwordController,
                      label: 'Mot de passe',
                      isObscured: _obscurePassword,
                      toggleObscured: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      validator: (value) {
                        if (value != null && value.isNotEmpty && value.length < 6) {
                          return 'Le mot de passe doit contenir au moins 6 caractères';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // 5. NOUVEAU : Confirmer mot de passe
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      label: 'Confirmer mot de passe',
                      isObscured: _obscureConfirmPassword,
                      toggleObscured: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                      validator: (value) {
                        if (_passwordController.text.isNotEmpty) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez confirmer votre mot de passe';
                          }
                          if (value != _passwordController.text) {
                            return 'Les mots de passe ne correspondent pas';
                          }
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // 6. Email
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre email';
                        }
                        if (!value.contains('@')) {
                          return 'Veuillez entrer un email valide';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // 7. Téléphone (Optionnel)
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Téléphone (Optionnel)',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: null,
                    ),
                    
                    SizedBox(height: 16),
                    
                    // 8. Ville
                    _buildTextField(
                      controller: _cityController,
                      label: 'Ville',
                      icon: Icons.location_city,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre ville';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 24),
                    
                    // 9. Notifications
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: SwitchListTile(
                        title: Row(
                          children: [
                            Icon(
                              Icons.notifications,
                              color: accentColor,
                              size: 22,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Notifications',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(left: 32.0),
                          child: Text(
                            'Recevoir des alertes sur la qualité de l\'air',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        value: _notificationsEnabled,
                        onChanged: (bool value) {
                          setState(() {
                            _notificationsEnabled = value;
                          });
                        },
                        activeColor: primaryColor,
                        activeTrackColor: accentColor.withOpacity(0.5),
                        inactiveThumbColor: Colors.grey.shade400,
                        inactiveTrackColor: Colors.grey.shade800,
                      ),
                    ),
                    
                    SizedBox(height: 30),
                    
                    // Bouton sauvegarder avec indication premium
                    ElevatedButton(
                      onPressed: _saveUserData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isPremiumUser ? Colors.amber : primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
                        shadowColor: (_isPremiumUser ? Colors.amber : primaryColor).withOpacity(0.4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_isPremiumUser ? Icons.star : Icons.save),
                          SizedBox(width: 10),
                          Text(
                            _isPremiumUser 
                              ? 'Sauvegarder (Premium)' 
                              : 'Sauvegarder mes infos',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: accentColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: _isPremiumUser ? Colors.amber : primaryColor, 
              width: 2
            ),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
        keyboardType: keyboardType,
        validator: validator,
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isObscured,
    required VoidCallback toggleObscured,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: Colors.white),
        obscureText: isObscured,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white70),
          prefixIcon: Icon(Icons.lock, color: accentColor),
          suffixIcon: IconButton(
            icon: Icon(
              isObscured ? Icons.visibility : Icons.visibility_off,
              color: Colors.white70,
            ),
            onPressed: toggleObscured,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: _isPremiumUser ? Colors.amber : primaryColor, 
              width: 2
            ),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
        validator: validator,
      ),
    );
  }
}