<#-- =============================================================================
     EIGEN IAM — Page de connexion nationale
     Template FreeMarker pour Keycloak — thème eigen-central
     Hérite de la logique Keycloak standard, surcharge uniquement le visuel.
     ============================================================================= -->
<#import "template.ftl" as layout>
<@layout.registrationLayout displayInfo=social.displayInfo displayWide=(realm.password && social.providers??)
                             bodyClass=(!realm.password && social.providers?? && !realm.registrationAllowed)?then('login-pf-page-wide', '');
                             section>
    <#if section = "header">
        <div class="eigen-header">
            <div class="eigen-logo-container">
                <div class="eigen-logo-mark">E</div>
                <div class="eigen-logo-text">
                    <span class="eigen-logo-main">EIGEN</span>
                    <span class="eigen-logo-sub">Système National d'Identité</span>
                </div>
            </div>
            <p class="eigen-subtitle">République Gabonaise — Ministère de l'Enseignement Supérieur</p>
        </div>
    <#elseif section = "form">
        <div id="kc-form" <#if realm.password && social.providers??>class="<#if realm.password && social.providers?? && (social.providers?size != 1)>pf-l-grid pf-m-gutter</#if>"</#if>>
            <div id="kc-form-wrapper" <#if realm.password && social.providers??>class="${properties.kcFormSocialAccountContentClass!} pf-l-grid__item"</#if>>
                <#if realm.password>
                    <form id="kc-form-login" onsubmit="login.disabled = true; return true;"
                          action="${url.loginAction}" method="post">

                        <#if !usernameHidden??>
                            <div class="${properties.kcFormGroupClass!}">
                                <label for="username" class="${properties.kcLabelClass!} eigen-label">
                                    <#if !realm.loginWithEmailAllowed>
                                        ${msg("username")}
                                    <#elseif !realm.registrationEmailAsUsername>
                                        Identifiant ou email national
                                    <#else>
                                        ${msg("email")}
                                    </#if>
                                </label>
                                <div class="eigen-input-group">
                                    <span class="eigen-input-icon">
                                        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                            <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>
                                        </svg>
                                    </span>
                                    <input tabindex="1" id="username"
                                           class="${properties.kcInputClass!} eigen-input"
                                           name="username" value="${(login.username!'')?html}"
                                           type="text"
                                           placeholder="ETU-2025-00412 ou nom.prenom"
                                           autofocus
                                           autocomplete="off"
                                    />
                                </div>
                            </div>
                        </#if>

                        <div class="${properties.kcFormGroupClass!}">
                            <label for="password" class="${properties.kcLabelClass!} eigen-label">
                                ${msg("password")}
                            </label>
                            <div class="eigen-input-group">
                                <span class="eigen-input-icon">
                                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                        <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>
                                    </svg>
                                </span>
                                <input tabindex="2" id="password"
                                       class="${properties.kcInputClass!} eigen-input"
                                       name="password" type="password"
                                       placeholder="Mot de passe"
                                       autocomplete="off"
                                />
                                <button type="button" class="eigen-password-toggle"
                                        onclick="togglePassword()" aria-label="Afficher/masquer le mot de passe">
                                    <svg id="eye-icon" xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                        <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/>
                                    </svg>
                                </button>
                            </div>
                        </div>

                        <div class="${properties.kcFormGroupClass!} eigen-form-options">
                            <div id="kc-form-options">
                                <#if realm.rememberMe && !usernameHidden??>
                                    <div class="checkbox">
                                        <label>
                                            <#if login.rememberMe??>
                                                <input tabindex="3" id="rememberMe" name="rememberMe" type="checkbox" checked> ${msg("rememberMe")}
                                            <#else>
                                                <input tabindex="3" id="rememberMe" name="rememberMe" type="checkbox"> ${msg("rememberMe")}
                                            </#if>
                                        </label>
                                    </div>
                                </#if>
                            </div>
                            <div class="eigen-forgot-password">
                                <#if realm.resetPasswordAllowed>
                                    <a tabindex="5" href="${url.loginResetCredentialsUrl}">
                                        Mot de passe oublié ?
                                    </a>
                                </#if>
                            </div>
                        </div>

                        <div id="kc-form-buttons" class="${properties.kcFormGroupClass!}">
                            <input type="hidden" id="id-hidden-input" name="credentialId"
                                   <#if auth.selectedCredential?has_content>value="${auth.selectedCredential}"</#if>/>
                            <input tabindex="4"
                                   class="eigen-btn-primary"
                                   name="login" id="kc-login"
                                   type="submit"
                                   value="Se connecter"/>
                        </div>

                        <div class="eigen-security-notice">
                            <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
                            </svg>
                            <span>Connexion sécurisée EIGEN — Vos données sont protégées</span>
                        </div>
                    </form>
                </#if>
            </div>

            <#if realm.password && social.providers??>
                <div id="kc-social-providers" class="${properties.kcFormSocialAccountContentClass!} pf-l-grid__item">
                    <hr class="eigen-divider"/>
                    <p class="eigen-divider-text">Connexion via votre établissement</p>
                    <ul class="${properties.kcFormSocialAccountListClass!} eigen-social-list">
                        <#list social.providers as p>
                            <li class="${properties.kcFormSocialAccountListLinkClass!}">
                                <a id="social-${p.alias}" class="eigen-social-btn" type="button" href="${p.loginUrl}">
                                    <div class="eigen-social-icon">
                                        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                            <rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/>
                                        </svg>
                                    </div>
                                    <span>${p.displayName!}</span>
                                </a>
                            </li>
                        </#list>
                    </ul>
                </div>
            </#if>
        </div>
    </#if>
</@layout.registrationLayout>

<script>
function togglePassword() {
    const pwd = document.getElementById('password');
    const icon = document.getElementById('eye-icon');
    if (pwd.type === 'password') {
        pwd.type = 'text';
        icon.innerHTML = '<path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/>';
    } else {
        pwd.type = 'password';
        icon.innerHTML = '<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/>';
    }
}
</script>
