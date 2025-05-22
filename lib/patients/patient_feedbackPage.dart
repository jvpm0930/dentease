import 'package:dentease/patients/patient_pagev2.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientFeedbackpage extends StatefulWidget {
  final String clinicId;

  const PatientFeedbackpage({super.key, required this.clinicId});

  @override
  State<PatientFeedbackpage> createState() => _PatientFeedbackpageState();
}

class _PatientFeedbackpageState extends State<PatientFeedbackpage> {
  final supabase = Supabase.instance.client;

  int selectedRating = 0;
  final TextEditingController feedbackController = TextEditingController();
  bool isSubmitting = false;
  String? errorMessage;

  Future<void> submitFeedback() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        errorMessage = "You must be logged in to submit feedback.";
      });
      return;
    }

    if (selectedRating == 0 || feedbackController.text.trim().isEmpty) {
      setState(() {
        errorMessage = "Please select a rating and enter feedback.";
      });
      return;
    }

    setState(() {
      isSubmitting = true;
      errorMessage = null;
    });

    try {
      // Check if the user already submitted feedback for this clinic
      final existing = await supabase
          .from('feedbacks')
          .select()
          .eq('patient_id', user.id)
          .eq('clinic_id', widget.clinicId)
          .maybeSingle();

      if (existing != null) {
        setState(() {
          errorMessage = "You have already submitted feedback for this clinic.";
        });
        return;
      }

      await supabase.from('feedbacks').insert({
        'rating': selectedRating,
        'feedback': feedbackController.text.trim(),
        'patient_id': user.id,
        'clinic_id': widget.clinicId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Feedback submitted successfully!")),
      );

      Navigator.pop(context); // Go back after submitting
    } catch (e) {
      setState(() {
        errorMessage = "Error submitting feedback: $e";
      });
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }


  Widget buildStar(int index) {
    return IconButton(
      icon: Icon(
        index <= selectedRating ? Icons.star : Icons.star_border,
        color: Colors.amber,
        size: 32,
      ),
      onPressed: () {
        setState(() {
          selectedRating = index;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rate Clinic"),
        centerTitle: true,
      ),
      resizeToAvoidBottomInset: true, // Important to prevent overflow
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("How was your experience?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Row(
                children: List.generate(5, (index) => buildStar(index + 1)),
              ),
              const SizedBox(height: 20),
              const Text("Leave a feedback:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(
                controller: feedbackController,
                maxLines: 4,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Write your feedback here...",
                ),
              ),
              const SizedBox(height: 20),
              if (errorMessage != null)
                Text(errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14)),
              const SizedBox(height: 10),
              isSubmitting
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: submitFeedback,
                      child: const Text("Submit Feedback"),
                    ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PatientPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.feedback),
                label: const Text("Not Now"),
              ),
            ],
          ),
        ),
      ),
    );

  }
}
