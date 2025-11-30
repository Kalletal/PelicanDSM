#!/bin/bash

# Pelican Panel - Dynamic Wizard Generator
# Generates install_uifile JSON with password confirmation validation

quote_json() {
    sed -e 's|\\|\\\\|g' -e 's|\"|\\\"|g'
}

# Password confirmation validator - checks both fields match
getPasswordConfirmValidator() {
    validator=$(/bin/cat<<'EOF'
{
    var confirmValue = arguments[0];
    var step = arguments[2];
    if (!step) return true;
    var pwField = step.getComponent("wizard_admin_password");
    if (!pwField) return true;
    var pwValue = pwField.getValue();
    if (confirmValue !== pwValue) {
        return "Les mots de passe ne correspondent pas";
    }
    return true;
}
EOF
)
    echo "$validator" | quote_json
}

# Re-validate confirmation when password field changes
getPasswordChangeHandler() {
    handler=$(/bin/cat<<'EOF'
{
    var pwValue = arguments[0];
    var step = arguments[2];
    if (!step) return true;
    var confirmField = step.getComponent("wizard_admin_password_confirm");
    if (confirmField) {
        confirmField.validate();
    }
    return true;
}
EOF
)
    echo "$handler" | quote_json
}

# Generate the wizard JSON
cat <<EOF > "${SYNOPKG_TEMP_LOGFILE}"
[
  {
    "step_title": "Configuration du Panel",
    "invalid_next_disabled_v2": true,
    "items": [
      {
        "desc": "<b>Important:</b> Entrez l'adresse IP de votre NAS ou un nom de domaine pointant vers celui-ci.<br><i>Ne laissez pas vide sauf si vous accédez uniquement depuis ce NAS.</i>"
      },
      {
        "type": "textfield",
        "desc": "Adresse IP du NAS ou nom de domaine (ex: 192.168.1.100 ou nas.mondomaine.fr)",
        "subitems": [
          {
            "key": "wizard_host",
            "desc": "Hôte du Panel",
            "defaultValue": "",
            "validator": {
              "allowBlank": false
            }
          }
        ]
      },
      {
        "type": "textfield",
        "desc": "Port HTTP pour accéder au Panel (défaut: 8080)",
        "subitems": [
          {
            "key": "wizard_port",
            "desc": "Port HTTP",
            "defaultValue": "8080",
            "validator": {
              "allowBlank": false,
              "regex": {
                "expr": "/^[0-9]+$/",
                "errorText": "Le port doit être un nombre"
              }
            }
          }
        ]
      },
      {
        "desc": "<br><b>URL finale:</b> <code>http://&lt;hôte&gt;:&lt;port&gt;</code>"
      }
    ]
  },
  {
    "step_title": "Compte Administrateur",
    "invalid_next_disabled_v2": true,
    "items": [
      {
        "desc": "<b>Créez le compte administrateur initial.</b><br>Ces identifiants vous permettront de vous connecter au Panel."
      },
      {
        "type": "textfield",
        "desc": "Adresse email de l'administrateur",
        "subitems": [
          {
            "key": "wizard_admin_email",
            "desc": "Email admin",
            "defaultValue": "admin@example.com",
            "validator": {
              "allowBlank": false,
              "regex": {
                "expr": "/^[^@]+@[^@]+\\\\.[^@]+$/",
                "errorText": "Entrez une adresse email valide"
              }
            }
          }
        ]
      },
      {
        "type": "textfield",
        "desc": "Nom d'utilisateur pour la connexion",
        "subitems": [
          {
            "key": "wizard_admin_username",
            "desc": "Nom d'utilisateur",
            "defaultValue": "admin",
            "validator": {
              "allowBlank": false,
              "minLength": 3
            }
          }
        ]
      },
      {
        "type": "password",
        "desc": "Mot de passe administrateur (min. 8 caractères)",
        "subitems": [
          {
            "key": "wizard_admin_password",
            "desc": "Mot de passe admin",
            "defaultValue": "",
            "validator": {
              "allowBlank": false,
              "minLength": 8,
              "fn": "$(getPasswordChangeHandler)"
            }
          }
        ]
      },
      {
        "type": "password",
        "desc": "Confirmez le mot de passe",
        "subitems": [
          {
            "key": "wizard_admin_password_confirm",
            "desc": "Confirmation",
            "defaultValue": "",
            "invalidText": "Les mots de passe ne correspondent pas",
            "validator": {
              "allowBlank": false,
              "fn": "$(getPasswordConfirmValidator)"
            }
          }
        ]
      },
      {
        "type": "combobox",
        "desc": "Langue de l'interface du Panel",
        "subitems": [
          {
            "key": "wizard_locale",
            "desc": "Langue",
            "defaultValue": "fr",
            "editable": false,
            "mode": "local",
            "store": ["fr", "en"],
            "displayField": "display",
            "valueField": "value"
          }
        ]
      },
      {
        "desc": "<br><i>Notez ces identifiants ! Vous pourrez modifier le mot de passe depuis le Panel après connexion.</i>"
      }
    ]
  },
  {
    "step_title": "Informations importantes",
    "items": [
      {
        "desc": "<b>Prérequis:</b><ul><li><b>Container Manager</b> (Docker) doit être installé</li><li>Connexion Internet pour télécharger l'image Docker (~500 MB)</li></ul>"
      },
      {
        "desc": "<br><b style='color:#e74c3c;'>IMPORTANT - Premier démarrage :</b><br><br>Le premier démarrage prend <b>5 à 10 minutes</b> pour :<ul><li>Télécharger l'image Docker (~500 MB)</li><li>Exécuter les migrations de base de données</li><li>Configurer l'application</li></ul><br>Une <b>page de chargement</b> s'affichera automatiquement pendant l'initialisation. Vous serez redirigé vers le Panel une fois prêt."
      },
      {
        "desc": "<br><hr><br><b>Configuration de Wings :</b><br>Consultez la <b>description du paquet</b> dans le Centre de paquets après l'installation."
      }
    ]
  }
]
EOF
