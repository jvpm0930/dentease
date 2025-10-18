import 'package:dentease/widgets/background_cont.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DentistServiceDetailsPage extends StatefulWidget {
  final String serviceId;

  const DentistServiceDetailsPage({super.key, required this.serviceId});

  @override
  _DentistServiceDetailsPageState createState() =>
      _DentistServiceDetailsPageState();
}

class _DentistServiceDetailsPageState extends State<DentistServiceDetailsPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  bool isLoading = true;
  String errorMessage = '';
  String serviceName = '';
  String servicePrice = '';
  String serviceDetails = '';
  String serviceStatus = '';

  @override
  void initState() {
    super.initState();
    _fetchServiceDetails();
  }

  Future<void> _fetchServiceDetails() async {
    try {
      final response = await supabase
          .from('services')
          .select('service_name, service_price, status, service_detail')
          .eq('service_id', widget.serviceId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          serviceName = response['service_name'] ?? '';
          servicePrice = response['service_price'] ?? '';
          serviceDetails = response['service_detail'] ?? '';
          serviceStatus = response['status'] ?? '';
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Service not found.";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching service details: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _updateService() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await supabase.from('services').update({
        'service_name': serviceName,
        'service_price': servicePrice,
        'service_detail' : serviceDetails,
        'status': serviceStatus
      }).eq('service_id', widget.serviceId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service updated successfully!')),
      );

      Navigator.pop(context, true); // Go back after update
    } catch (e) {
      setState(() {
        errorMessage = 'Error updating service: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundCont(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Service details",
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage.isNotEmpty
                ? Center(
                    child: Text(errorMessage,
                        style: const TextStyle(color: Colors.red)))
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            initialValue: serviceName,
                            decoration: const InputDecoration(
                              labelText: "Service Name",
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => setState(() {
                              serviceName = value;
                            }),
                            validator: (value) =>
                                value!.isEmpty ? "Enter service name" : null,
                          ),
                          const SizedBox(height: 15),
                          TextFormField(
                            initialValue: servicePrice,
                            decoration: const InputDecoration(
                              labelText: "Service Price (PHP)",
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => setState(() {
                              servicePrice = value;
                            }),
                            validator: (value) =>
                                value!.isEmpty ? "Enter service price" : null,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                minLines: null, // starting height
                                maxLines: null,
                          ),
                          const SizedBox(height: 15),
                          TextFormField(
                            initialValue: serviceDetails,
                            decoration: const InputDecoration(
                              labelText: "Service Details",
                              border: OutlineInputBorder(),
                              alignLabelWithHint:
                                  true, // keeps label aligned at the top when multiline
                            ),
                            onChanged: (value) => setState(() {
                              serviceDetails = value;
                            }),
                            validator: (value) =>
                                value!.isEmpty ? "Enter service details" : null,

                            // Multiline settings
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            minLines: null, // starting height
                            maxLines:
                                null, // expand up to this many lines (or use null for unlimited)
                          ),
                          const SizedBox(height: 15),
                          
                          DropdownButtonFormField<String>(
                            value: serviceStatus,
                            decoration: const InputDecoration(
                              labelText: "Status",
                              border: OutlineInputBorder(),
                            ),
                            items: ['active', 'inactive']
                                .map((status) => DropdownMenuItem(
                                      value: status,
                                      child: Text(status),
                                    ))
                                .toList(),
                            onChanged: (value) => setState(() {
                              serviceStatus = value!;
                            }),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _updateService,
                              child: const Text("Update Service"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
