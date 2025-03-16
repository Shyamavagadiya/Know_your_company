import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmailParsingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Parse new unprocessed emails
  Future<void> parseNewEmails() async {
    try {
      // Get unprocessed emails
      QuerySnapshot emailsSnapshot = await _firestore
          .collection('emails')
          .where('processed', isEqualTo: false)
          .get();

      for (var doc in emailsSnapshot.docs) {
        Map<String, dynamic> emailData = doc.data() as Map<String, dynamic>;
        String emailId = doc.id;

        // Check if email is from a recognized company domain
        if (_isPlacementEmail(emailData)) {
          // Extract placement details
          Map<String, dynamic>? placementDetails = _extractPlacementDetails(emailData);

          if (placementDetails != null) {
            // Create a new placement drive
            DocumentReference driveRef = await _firestore.collection('placementDrives').add({
              ...placementDetails,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedBy': _auth.currentUser?.uid ?? 'system',
              'postedFromEmail': emailData['from'],
              'emailReceivedAt': emailData['receivedAt'],
              'status': 'upcoming',
            });

            // Update email with reference to created drive
            await _firestore.collection('emails').doc(emailId).update({
              'processed': true,
              'driveId': driveRef.id,
            });

            // Send notifications to eligible students
            await _notifyEligibleStudents(driveRef.id, placementDetails);
          }
        }

        // Mark email as processed even if it's not a placement email
        if (!emailData['processed']) {
          await _firestore.collection('emails').doc(emailId).update({
            'processed': true,
          });
        }
      }
    } catch (e) {
      print('Error parsing emails: $e');
      rethrow;
    }
  }

  // Check if the email is a placement email
  bool _isPlacementEmail(Map<String, dynamic> emailData) {
    String subject = emailData['subject'].toLowerCase();
    String body = emailData['body'].toLowerCase();

    // Check for common keywords in placement emails
    List<String> keywords = [
      'placement', 'recruitment', 'job', 'career', 'opportunity',
      'hiring', 'internship', 'campus', 'interview', 'position'
    ];

    return keywords.any((keyword) => subject.contains(keyword) || body.contains(keyword));
  }

  // Extract placement details from the email
  Map<String, dynamic>? _extractPlacementDetails(Map<String, dynamic> emailData) {
    String body = emailData['body'];
    String subject = emailData['subject'];

    // Extract company name (simplified)
    String? companyName = _extractCompanyName(subject, body);

    if (companyName == null) {
      return null;
    }

    // Extract job role (simplified)
    String jobRole = _extractJobRole(subject, body) ?? 'Position';

    // Extract basic details
    return {
      'companyId': '', // Will need to be set if company exists or new one created
      'title': '$companyName - $jobRole',
      'description': body.substring(0, body.length > 500 ? 500 : body.length),
      'jobRole': jobRole,
      'package': {
        'ctc': 0, // To be updated manually
        'breakdown': '',
      },
      'eligibility': {
        'courses': [],
        'branches': [],
        'cgpaCutoff': 0.0,
        'backlogs': 0,
        'otherCriteria': '',
      },
      'schedule': {
        'registrationDeadline': Timestamp.now().toDate().add(Duration(days: 7)),
        'rounds': [
          {
            'roundNumber': 1,
            'roundName': 'Initial Screening',
            'description': 'Resume shortlisting',
            'date': Timestamp.now().toDate().add(Duration(days: 10)),
            'venue': 'To be announced',
          },
        ],
      },
    };
  }

  // Extract company name from email subject or body
  String? _extractCompanyName(String subject, String body) {
    List<String> companyIndicators = ['from', 'at', 'with', 'by', 'company', 'organization'];

    // Try to extract from subject first
    for (var indicator in companyIndicators) {
      if (subject.toLowerCase().contains(indicator)) {
        int index = subject.toLowerCase().indexOf(indicator);
        if (index + indicator.length < subject.length - 5) {
          String potentialCompany = subject.substring(index + indicator.length, index + indicator.length + 20);
          return potentialCompany.trim();
        }
      }
    }

    // Fallback to email sender domain
    return 'Company';
  }

  // Extract job role from email subject or body
  String? _extractJobRole(String subject, String body) {
    List<String> roleIndicators = ['role', 'position', 'job', 'opening', 'vacancy', 'hiring'];

    // Try to extract from subject first
    for (var indicator in roleIndicators) {
      if (subject.toLowerCase().contains(indicator)) {
        int index = subject.toLowerCase().indexOf(indicator);
        if (index + indicator.length < subject.length - 5) {
          String potentialRole = subject.substring(index + indicator.length, index + indicator.length + 20);
          return potentialRole.trim();
        }
      }
    }

    // Fallback
    return 'Position';
  }

  // Notify eligible students about the new placement drive
  Future<void> _notifyEligibleStudents(String driveId, Map<String, dynamic> placementDetails) async {
    // Get all students
    QuerySnapshot studentsSnapshot = await _firestore.collection('students').get();

    for (var studentDoc in studentsSnapshot.docs) {
      String studentId = studentDoc.id;

      // Create a notification for each student
      await _firestore.collection('notifications').add({
        'recipientId': studentId,
        'title': 'New Placement Opportunity',
        'body': 'A new placement drive has been posted: ${placementDetails['title']} - Apply now!',
        'type': 'new_drive',
        'data': {
          'driveId': driveId,
        },
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.now().toDate().add(Duration(days: 7)),
      });
    }
  }
}