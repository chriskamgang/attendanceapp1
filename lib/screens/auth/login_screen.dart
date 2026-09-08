import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../bus/app/core/widgets/brutal_button.dart';
import '../../bus/app/data/services/api_exception.dart';
import '../../bus/app/data/services/session_service.dart';
import '../../bus/bus_boot.dart';
import '../../main.dart';
import '../../launcher/app_mode.dart';
import '../../launcher/switch_space_button.dart';
import '../../providers/auth_provider.dart';
import '../../shared/rh_ui.dart';
import '../../utils/constants.dart';

/// Connexion à Estuaire RH.
///
/// L'écran porte aussi la seule entrée visible vers INSAM BUS : les
/// étudiants et les chauffeurs n'ont pas de compte de pointage, et
/// c'est par ici qu'ils rejoignent leur espace.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _motDePasseMasque = true;
  bool _enCours = false;

  /// Case « Je suis chauffeur » : bascule le formulaire sur place.
  ///
  /// Le chauffeur est créé au back-office, où le **numéro de téléphone**
  /// fait foi : ce n'est pas le même identifiant ni le même service
  /// d'authentification que l'employé, mais c'est le même écran — l'envoyer
  /// ailleurs pour deux champs identiques n'apporterait rien.
  bool _estChauffeur = false;

  final _telephoneController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  /// Bascule entre les deux publics.
  ///
  /// La saisie n'est pas vidée : l'employé qui coche par curiosité retrouve
  /// son adresse en décochant.
  void _basculerChauffeur(bool valeur) {
    if (valeur == _estChauffeur) return;
    setState(() => _estChauffeur = valeur);
  }

  Future<void> _seConnecter() async {
    if (!_formKey.currentState!.validate()) return;

    if (_estChauffeur) {
      await _connecterChauffeur();
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _enCours = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final resultat = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _enCours = false);

    if (resultat['success'] == true) {
      HapticFeedback.heavyImpact();
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      _signalerErreur(resultat['message'] ?? 'Erreur de connexion');
    }
  }

  /// Connexion du chauffeur, contre le backend du transport.
  ///
  /// Ses services vivent dans l'espace étudiant : on les installe ici — la
  /// manœuvre est idempotente — pour authentifier sans quitter cet écran,
  /// puis on bascule vers son espace une fois la session ouverte.
  Future<void> _connecterChauffeur() async {
    HapticFeedback.mediumImpact();
    setState(() => _enCours = true);

    try {
      await BusBoot.demarrer();

      final utilisateur = await Get.find<SessionService>().signInDriver(
        phone: _telephoneController.text.replaceAll(' ', '').trim(),
        pin: _passwordController.text,
      );

      if (!mounted) return;
      HapticFeedback.heavyImpact();

      // L'espace du transport prend la main : le splash y reconnaît la
      // session déjà ouverte et mène droit à l'écran du chauffeur.
      PorteEntreeService.annoncer(PorteEntree.chauffeur);
      await RootApp.allerVers(AppMode.insamBus);

      // La bascule remplace l'application : rien à faire de plus ici, et
      // `utilisateur` n'a servi qu'à faire remonter un éventuel refus.
      debugPrint('Chauffeur connecté : ${utilisateur.role}');
    } on ApiException catch (e) {
      if (!mounted) return;
      _signalerErreur(
          e.errorFor('telephone') ?? e.errorFor('pin') ?? e.message);
    } catch (_) {
      if (!mounted) return;
      _signalerErreur('Connexion impossible. Réessaie dans un instant.');
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  void _signalerErreur(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Brutal.radiusSmall),
            side: const BorderSide(color: AppColors.ink, width: Brutal.border),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, contraintes) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: contraintes.maxHeight - 52,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _EnTete(),
                    const SizedBox(height: 28),
                    _formulaire(),
                    const SizedBox(height: 18),
                    const _PorteEtudiant(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _formulaire() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
        boxShadow: Brutal.shadow(Brutal.shadowOffsetLarge),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RhSectionTitle('Connexion'),
            const SizedBox(height: 18),

            // Le champ suit la case : une adresse pour l'employé, un numéro
            // pour le chauffeur — c'est ainsi que le backend les distingue.
            if (_estChauffeur)
              _champ(
                controller: _telephoneController,
                label: 'Numéro de téléphone',
                hint: '+237 6 XX XX XX XX',
                icone: Icons.phone_outlined,
                clavier: TextInputType.phone,
                validation: (valeur) {
                  final compact = (valeur ?? '').replaceAll(' ', '');
                  if (compact.isEmpty) return 'Entre ton numéro de téléphone';
                  if (!RegExp(r'^\+?\d{8,15}$').hasMatch(compact)) {
                    return 'Ce numéro est invalide';
                  }
                  return null;
                },
              )
            else
              _champ(
                controller: _emailController,
                label: 'Adresse email',
                hint: 'nom@insam.cm',
                icone: Icons.mail_outline_rounded,
                clavier: TextInputType.emailAddress,
                validation: (valeur) {
                  if (valeur == null || valeur.isEmpty) {
                    return 'Entre ton adresse email';
                  }
                  if (!valeur.contains('@')) return 'Adresse email invalide';
                  return null;
                },
              ),
            const SizedBox(height: 15),

            _champ(
              controller: _passwordController,
              label: 'Mot de passe',
              hint: '••••••••',
              icone: Icons.lock_outline_rounded,
              masque: _motDePasseMasque,
              suffixe: IconButton(
                icon: Icon(
                  _motDePasseMasque
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.inkMuted,
                  size: 21,
                ),
                onPressed: () => setState(
                  () => _motDePasseMasque = !_motDePasseMasque,
                ),
              ),
              validation: (valeur) {
                if (valeur == null || valeur.isEmpty) {
                  return 'Entre ton mot de passe';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            _CaseChauffeur(
              coche: _estChauffeur,
              onChange: _basculerChauffeur,
            ),
            const SizedBox(height: 20),

            BrutalButton(
              label: _enCours ? 'CONNEXION…' : 'SE CONNECTER',
              icon: _enCours ? null : Icons.arrow_forward_rounded,
              iconTrailing: true,
              // Le bouton reste affiché mais inerte pendant l'appel : le
              // retirer ferait sauter la mise en page sous le doigt.
              onPressed: _enCours ? null : _seConnecter,
            ),
          ],
        ),
      ),
    );
  }

  Widget _champ({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icone,
    TextInputType? clavier,
    bool masque = false,
    Widget? suffixe,
    String? Function(String?)? validation,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: clavier,
      obscureText: masque,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          color: AppColors.inkMuted,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppColors.red,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
        hintStyle: const TextStyle(color: AppColors.inkMuted, fontSize: 14),
        prefixIcon: Icon(icone, color: AppColors.blueDark, size: 21),
        suffixIcon: suffixe,
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: _bordure(AppColors.ink, Brutal.border),
        enabledBorder: _bordure(AppColors.ink, Brutal.border),
        focusedBorder: _bordure(AppColors.red, Brutal.borderThick),
        errorBorder: _bordure(AppColors.danger, Brutal.border),
        focusedErrorBorder: _bordure(AppColors.danger, Brutal.borderThick),
        errorStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.danger,
        ),
      ),
      validator: validation,
    );
  }

  OutlineInputBorder _bordure(Color couleur, double epaisseur) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(Brutal.radiusSmall),
      borderSide: BorderSide(color: couleur, width: epaisseur),
    );
  }
}

/// Marque et titre de l'application.
class _EnTete extends StatelessWidget {
  const _EnTete();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 66,
          height: 66,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.ink, width: Brutal.border),
            boxShadow: Brutal.shadow(const Offset(3, 3)),
          ),
          child: ClipOval(
            child: Image.asset('assets/img/insam.png', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          AppConstants.appName.toUpperCase(),
          style: const TextStyle(
            fontSize: 33,
            height: 1.02,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
            color: AppColors.blueDark,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(width: 4, height: 15, color: AppColors.red),
            const SizedBox(width: 8),
            const Text(
              'Pointage par géolocalisation',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Entrée vers l'espace étudiant.
///
/// Volontairement en retrait : ce formulaire-ci est celui du personnel, et
/// l'étudiant n'a pas de compte de pointage. Le libellé ne le renvoie plus
/// au seul transport — la navette n'est qu'un volet de sa scolarité, à côté
/// de son emploi du temps et de ses cours — sans quoi celui qui ne prend
/// pas le bus ne se reconnaissait pas dans la porte qui lui était destinée.
class _PorteEtudiant extends StatelessWidget {
  const _PorteEtudiant();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Brutal.radius),
        onTap: () {
          PorteEntreeService.annoncer(PorteEntree.etudiant);
          SwitchSpaceButton.demander(context, AppMode.insamBus);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.blueSoft,
            borderRadius: BorderRadius.circular(Brutal.radius),
            border: Border.all(color: AppColors.ink, width: Brutal.border),
            boxShadow: Brutal.shadow(const Offset(3, 3)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.blueDark,
                  borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                  border: Border.all(color: AppColors.ink, width: 1.8),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Espace étudiant',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Emploi du temps, cours et navette',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.ink,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Case « Je suis chauffeur ».
///
/// Elle transforme le formulaire sur place — le champ passe de l'adresse
/// email au numéro de téléphone — plutôt que d'ouvrir un second écran :
/// c'est la même connexion, avec un identifiant différent, et le chauffeur
/// n'a pas à traverser une page de plus pour saisir deux champs.
class _CaseChauffeur extends StatelessWidget {
  const _CaseChauffeur({required this.coche, required this.onChange});

  final bool coche;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChange(!coche),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: coche ? AppColors.blueSoft : AppColors.white,
          borderRadius: BorderRadius.circular(Brutal.radiusSmall),
          border: Border.all(color: AppColors.ink, width: Brutal.border),
          boxShadow: coche ? Brutal.shadow(const Offset(3, 3)) : null,
        ),
        child: Row(
          children: [
            // Case dessinée à la main : la Checkbox de Material jure avec
            // les bordures épaisses du reste de l'écran.
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 23,
              height: 23,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: coche ? AppColors.blue : AppColors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: AppColors.ink, width: 2.2),
              ),
              child: coche
                  ? const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: AppColors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 11),
            const Icon(
              Icons.directions_bus_filled_rounded,
              size: 18,
              color: AppColors.ink,
            ),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'Je suis chauffeur',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
