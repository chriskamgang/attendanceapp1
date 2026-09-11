import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Champ de saisie encadré, avec libellé au-dessus et message d'erreur dessous.
class BrutalField extends StatelessWidget {
  const BrutalField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.error = '',
    this.onSubmitted,
    this.obscure = false,
    this.onToggleObscure,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String error;
  final ValueChanged<String>? onSubmitted;

  /// Masque la saisie : mot de passe du chauffeur, souvent tapé sous le
  /// regard des étudiants qui montent.
  final bool obscure;

  /// Affiche l'œil de bascule quand le champ est masquable.
  final VoidCallback? onToggleObscure;

  /// Ouvre le clavier sur ce champ : utile quand c'est la seule saisie
  /// qui reste à faire.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final hasError = error.isNotEmpty;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: text.bodyMedium?.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(Brutal.radius),
            border: Border.all(
              color: hasError
                  ? Theme.of(context).colorScheme.error
                  : AppColors.ink,
              width: Brutal.border,
            ),
            boxShadow: Brutal.shadow(const Offset(3, 3)),
          ),
          child: Row(
            children: [
              if (icon != null)
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Icon(icon, size: 20, color: AppColors.inkMuted),
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: autofocus,
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  textCapitalization: textCapitalization,
                  onSubmitted: onSubmitted,
                  cursorColor: AppColors.blue,
                  style: text.titleMedium?.copyWith(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: text.bodyMedium?.copyWith(fontSize: 15.5),
                    // Le cadre est celui du Container qui entoure ce champ :
                    // les contours du thème s'y ajouteraient en doublon.
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: icon == null ? 16 : 12,
                      vertical: 18,
                    ),
                  ),
                ),
              ),
              if (onToggleObscure != null)
                GestureDetector(
                  onTap: onToggleObscure,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Icon(
                      obscure
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      size: 20,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 15,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  error,
                  style: text.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
