/*
 * Harborline Backstage frontend (new frontend system). Plugins are discovered from package.json
 * (`app.packages: all` in app-config.yaml); this file only customises sign-in.
 */
import React from 'react';
import { createApp } from '@backstage/frontend-defaults';
import {
  createFrontendModule,
  SignInPageBlueprint,
} from '@backstage/frontend-plugin-api';
import { SignInPage } from '@backstage/core-components';
import { microsoftAuthApiRef } from '@backstage/core-plugin-api';

const harborlineSignIn = SignInPageBlueprint.make({
  params: {
    loader: async () => props => (
      <SignInPage
        {...props}
        provider={{
          id: 'microsoft-auth-provider',
          title: 'Microsoft Entra ID',
          message: 'Sign in with your Harborline account',
          apiRef: microsoftAuthApiRef,
        }}
      />
    ),
  },
});

const app = createApp({
  features: [
    createFrontendModule({
      pluginId: 'app',
      extensions: [harborlineSignIn],
    }),
  ],
});

export default app.createRoot();
