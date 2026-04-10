
import { 
  collection, 
  doc, 
  addDoc, 
  getDocs, 
  getDoc,
  updateDoc, 
  deleteDoc,
  query, 
  where, 
  onSnapshot,
  Timestamp,
  getDocFromServer,
  writeBatch
} from 'firebase/firestore';
import { db, auth } from '../firebase';
import { Medication, MedicationPlan, ReminderEvent, IntakeRecord } from '../types';

enum OperationType {
  CREATE = 'create',
  UPDATE = 'update',
  DELETE = 'delete',
  LIST = 'list',
  GET = 'get',
  WRITE = 'write',
}

interface FirestoreErrorInfo {
  error: string;
  operationType: OperationType;
  path: string | null;
  authInfo: {
    userId: string | undefined;
    email: string | null | undefined;
    emailVerified: boolean | undefined;
    isAnonymous: boolean | undefined;
    tenantId: string | null | undefined;
    providerInfo: {
      providerId: string;
      displayName: string | null;
      email: string | null;
      photoUrl: string | null;
    }[];
  }
}

function handleFirestoreError(error: unknown, operationType: OperationType, path: string | null) {
  const errInfo: FirestoreErrorInfo = {
    error: error instanceof Error ? error.message : String(error),
    authInfo: {
      userId: auth.currentUser?.uid,
      email: auth.currentUser?.email,
      emailVerified: auth.currentUser?.emailVerified,
      isAnonymous: auth.currentUser?.isAnonymous,
      tenantId: auth.currentUser?.tenantId,
      providerInfo: auth.currentUser?.providerData.map(provider => ({
        providerId: provider.providerId,
        displayName: provider.displayName,
        email: provider.email,
        photoUrl: provider.photoURL
      })) || []
    },
    operationType,
    path
  };
  console.error('Firestore Error: ', JSON.stringify(errInfo));
  throw new Error(JSON.stringify(errInfo));
}

class MedicationService {
  async testConnection() {
    try {
      await getDocFromServer(doc(db, 'test', 'connection'));
    } catch (error) {
      if(error instanceof Error && error.message.includes('the client is offline')) {
        console.error("Please check your Firebase configuration. ");
      }
    }
  }

  async getBindings(userId: string) {
    try {
      const q = query(collection(db, 'elder_bindings'), where('managerUserId', '==', userId));
      const snapshot = await getDocs(q);
      return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    } catch (error) {
      handleFirestoreError(error, OperationType.LIST, 'elder_bindings');
      return [];
    }
  }

  async bindElder(managerUserId: string, shortId: string, phoneLast4: string) {
    try {
      // Find the elder user by shortId
      const usersRef = collection(db, 'users');
      const q = query(usersRef, where('shortId', '==', shortId));
      const snapshot = await getDocs(q);
      
      if (snapshot.empty) {
        throw new Error('未找到该 ID 的用户');
      }

      const elderDoc = snapshot.docs[0];
      const elderData = elderDoc.data();

      // Verify phone last 4 digits
      if (!elderData.phone || !elderData.phone.endsWith(phoneLast4)) {
        throw new Error('手机尾号不匹配');
      }

      if (elderDoc.id === managerUserId) {
        throw new Error('不能绑定自己');
      }

      // Check if already bound
      const existingQ = query(
        collection(db, 'elder_bindings'), 
        where('managerUserId', '==', managerUserId),
        where('elderUserId', '==', elderDoc.id)
      );
      const existingSnapshot = await getDocs(existingQ);
      if (!existingSnapshot.empty) {
        throw new Error('已经绑定过该用户');
      }

      // Create binding
      const bindingData = {
        managerUserId,
        elderUserId: elderDoc.id,
        relationType: 'family',
        canViewRecords: true,
        canViewImages: true,
        canReceiveAlerts: true,
        canEditPlans: true,
        active: true,
        createdAt: new Date().toISOString()
      };

      await addDoc(collection(db, 'elder_bindings'), bindingData);
      return { success: true, elderId: elderDoc.id };
    } catch (error: any) {
      if (error.message.includes('未找到') || error.message.includes('不匹配') || error.message.includes('不能') || error.message.includes('已经')) {
        throw error;
      }
      handleFirestoreError(error, OperationType.CREATE, 'elder_bindings');
      throw error;
    }
  }

  async getMedications(targetUserId: string): Promise<Medication[]> {
    const path = 'medications';
    try {
      const q = query(collection(db, path), where('targetUserId', '==', targetUserId), where('archived', '==', false));
      const snapshot = await getDocs(q);
      return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Medication));
    } catch (error) {
      handleFirestoreError(error, OperationType.LIST, path);
      return [];
    }
  }

  async getPlans(targetUserId: string): Promise<MedicationPlan[]> {
    const path = 'plans';
    try {
      const q = query(collection(db, path), where('targetUserId', '==', targetUserId));
      const snapshot = await getDocs(q);
      return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as MedicationPlan));
    } catch (error) {
      handleFirestoreError(error, OperationType.LIST, path);
      return [];
    }
  }

  async addMedication(med: Omit<Medication, 'id' | 'createdAt' | 'updatedAt'>): Promise<string> {
    const path = 'medications';
    try {
      const docRef = await addDoc(collection(db, path), {
        ...med,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });
      return docRef.id;
    } catch (error) {
      handleFirestoreError(error, OperationType.CREATE, path);
      return '';
    }
  }

  async updateMedication(id: string, updates: Partial<Medication>): Promise<void> {
    const path = `medications/${id}`;
    try {
      const docRef = doc(db, 'medications', id);
      await updateDoc(docRef, {
        ...updates,
        updatedAt: new Date().toISOString(),
      });
    } catch (error) {
      handleFirestoreError(error, OperationType.UPDATE, path);
    }
  }

  async deleteMedication(id: string): Promise<void> {
    const path = `medications/${id}`;
    try {
      const docRef = doc(db, 'medications', id);
      await updateDoc(docRef, { archived: true });
    } catch (error) {
      handleFirestoreError(error, OperationType.DELETE, path);
    }
  }

  async getTodayReminders(targetUserId: string): Promise<ReminderEvent[]> {
    const path = 'reminders';
    try {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const tomorrow = new Date(today);
      tomorrow.setDate(tomorrow.getDate() + 1);

      const q = query(
        collection(db, path), 
        where('targetUserId', '==', targetUserId),
        where('dueTime', '>=', today.toISOString()),
        where('dueTime', '<', tomorrow.toISOString())
      );
      const snapshot = await getDocs(q);
      return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as ReminderEvent));
    } catch (error) {
      handleFirestoreError(error, OperationType.LIST, path);
      return [];
    }
  }

  subscribeToTodayReminders(targetUserId: string, callback: (events: ReminderEvent[]) => void) {
    const path = 'reminders';
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const q = query(
      collection(db, path), 
      where('targetUserId', '==', targetUserId),
      where('dueTime', '>=', today.toISOString()),
      where('dueTime', '<', tomorrow.toISOString())
    );

    return onSnapshot(q, (snapshot) => {
      const events = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as ReminderEvent));
      // Sort by dueTime
      events.sort((a, b) => new Date(a.dueTime).getTime() - new Date(b.dueTime).getTime());
      callback(events);
    }, (error) => {
      handleFirestoreError(error, OperationType.LIST, path);
    });
  }

  async confirmIntake(eventId: string, userId: string): Promise<void> {
    const path = `reminders/${eventId}`;
    try {
      const eventRef = doc(db, 'reminders', eventId);
      await updateDoc(eventRef, {
        status: 'taken',
        confirmedAt: new Date().toISOString()
      });
    } catch (error) {
      handleFirestoreError(error, OperationType.UPDATE, path);
    }
  }

  async deleteReminder(eventId: string): Promise<void> {
    const path = `reminders/${eventId}`;
    try {
      const eventRef = doc(db, 'reminders', eventId);
      await deleteDoc(eventRef);
    } catch (error) {
      handleFirestoreError(error, OperationType.DELETE, path);
    }
  }

  async addMedicationPlan(plan: Omit<MedicationPlan, 'id' | 'createdAt' | 'updatedAt'>): Promise<string> {
    const path = 'plans';
    try {
      // Fetch medicine name for denormalization into reminders
      const medDoc = await getDoc(doc(db, 'medications', plan.medicineId));
      const medicineName = medDoc.exists() ? medDoc.data().name : '药品';

      const batch = writeBatch(db);
      const planRef = doc(collection(db, 'plans'));
      const createdAt = new Date().toISOString();
      
      batch.set(planRef, {
        ...plan,
        createdAt,
        updatedAt: createdAt,
      });
      
      // Generate initial reminders for today
      const now = new Date();
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      for (const schedule of plan.schedules) {
        const dueTime = new Date(today);
        dueTime.setHours(schedule.hour, schedule.minute, 0, 0);
        
        // Only create reminder if it's in the future (or very recent past for testing/drift)
        if (dueTime.getTime() > now.getTime() - 5 * 60 * 1000) {
          const reminderRef = doc(collection(db, 'reminders'));
          batch.set(reminderRef, {
            targetUserId: plan.targetUserId,
            planId: planRef.id,
            medicineName, // Denormalized name
            scheduleId: '', // We don't have schedule IDs yet in this simplified model
            dueTime: dueTime.toISOString(),
            status: 'pending',
            createdAt
          });
        }
      }

      await batch.commit();
      return planRef.id;
    } catch (error) {
      handleFirestoreError(error, OperationType.CREATE, path);
      return '';
    }
  }

  async addTestReminder(userId: string): Promise<void> {
    const path = 'reminders';
    try {
      const now = new Date();
      const testTime = new Date(now.getTime() + 5000); // 5 seconds from now
      
      await addDoc(collection(db, path), {
        targetUserId: userId,
        planId: 'test-plan',
        scheduleId: 'test-schedule',
        dueTime: testTime.toISOString(),
        status: 'pending',
        createdAt: now.toISOString()
      });
    } catch (error) {
      handleFirestoreError(error, OperationType.CREATE, path);
    }
  }
}

export const medicationService = new MedicationService();
medicationService.testConnection();
