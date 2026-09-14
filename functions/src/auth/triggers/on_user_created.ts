import * as functions from "firebase-functions/v1";
import * as logger from "firebase-functions/logger";
import {UserRecord} from "firebase-admin/auth";
import {REGION} from "../../config/firebase";
import {AuthService} from "../services/auth_service";

/**
 * Auth Trigger: Fires whenever a new user is created in Firebase Authentication
 * (via Email/Password or Google Sign-In).
 */
export const onUserCreated = functions
  .region(REGION)
  .auth.user()
  .onCreate(async (user: UserRecord) => {
    logger.info(`[AuthTrigger] Processing new user registration: ${user.uid} (${user.email})`);
    try {
      await AuthService.handleNewUser(user);
    } catch (error) {
      logger.error(`[AuthTrigger] Failed to initialize user ${user.uid}:`, {
        uid: user.uid,
        email: user.email,
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined,
      });
      throw error;
    }
  });
