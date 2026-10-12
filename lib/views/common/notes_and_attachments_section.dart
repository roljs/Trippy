import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/attachment_upload_helper.dart';

class NotesAndAttachmentsSection extends StatefulWidget {
  final TextEditingController notesController;
  final List<String> links;
  final ValueChanged<List<String>> onLinksChanged;
  final List<String> attachments;
  final ValueChanged<List<String>> onAttachmentsChanged;
  final String? notesLabel;
  final String? notesHint;
  final String? tripId;

  const NotesAndAttachmentsSection({
    super.key,
    required this.notesController,
    required this.links,
    required this.onLinksChanged,
    required this.attachments,
    required this.onAttachmentsChanged,
    this.notesLabel,
    this.notesHint,
    this.tripId,
  });

  @override
  State<NotesAndAttachmentsSection> createState() =>
      _NotesAndAttachmentsSectionState();
}

class _NotesAndAttachmentsSectionState
    extends State<NotesAndAttachmentsSection> {
  bool _isUploading = false;
  String _uploadStatusMessage = '';

  Future<String?> _promptFriendlyName({
    required String title,
    required String defaultName,
  }) async {
    final controller = TextEditingController(text: defaultName);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.label_outline_rounded,
                color: AppColors.stay, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Friendly Name',
            hintText: 'e.g. Flight Tickets, Hotel Confirmation, eVisa',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, defaultName),
            child: const Text('Use Default'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save Name'),
          ),
        ],
      ),
    );
  }

  void _showAddLinkDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.link_rounded, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('Add Link', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Friendly Name (Optional)',
                hintText: 'e.g. Official Tickets, Guide, Booking Page',
                prefixIcon: Icon(Icons.label_outline_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL / Link *',
                hintText: 'https://example.com/tickets',
                prefixIcon: Icon(Icons.http_rounded, size: 18),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                final entry = AttachmentUploadHelper.encodeNamedEntry(
                  urlOrPath: url,
                  friendlyName: nameController.text.trim(),
                );
                final updated = List<String>.from(widget.links)..add(entry);
                widget.onLinksChanged(updated);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditLinkDialog(int index) {
    final current = widget.links[index];
    final nameController = TextEditingController(
      text: AttachmentUploadHelper.extractFriendlyName(current) ?? '',
    );
    final urlController = TextEditingController(
      text: AttachmentUploadHelper.extractUrlOrPath(current),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('Edit Link', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('edit_link_name_field'),
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Friendly Name (Optional)',
                hintText: 'e.g. Official Tickets, Guide, Booking Page',
                prefixIcon: Icon(Icons.label_outline_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('edit_link_url_field'),
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL / Link *',
                hintText: 'https://example.com/tickets',
                prefixIcon: Icon(Icons.http_rounded, size: 18),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                final entry = AttachmentUploadHelper.encodeNamedEntry(
                  urlOrPath: url,
                  friendlyName: nameController.text.trim(),
                );
                final updated = List<String>.from(widget.links);
                updated[index] = entry;
                widget.onLinksChanged(updated);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddAttachmentDialog() {
    final nameController = TextEditingController();
    final pathController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.attach_file_rounded, color: AppColors.stay, size: 20),
            SizedBox(width: 8),
            Text('Add Attachment Manually', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Friendly Name (Optional)',
                hintText: 'e.g. Flight Voucher, Hotel Receipt, eVisa',
                prefixIcon: Icon(Icons.label_outline_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pathController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'File Name or URL *',
                hintText: 'e.g. Flight_Voucher.pdf or https://...',
                prefixIcon: Icon(Icons.description_outlined, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final path = pathController.text.trim();
              if (path.isNotEmpty) {
                final entry = AttachmentUploadHelper.encodeNamedEntry(
                  urlOrPath: path,
                  friendlyName: nameController.text.trim(),
                );
                final updated = List<String>.from(widget.attachments)
                  ..add(entry);
                widget.onAttachmentsChanged(updated);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditAttachmentDialog(int index) {
    final current = widget.attachments[index];
    final defaultLabel = AttachmentUploadHelper.formatAttachmentLabel(current);
    final nameController = TextEditingController(
      text: AttachmentUploadHelper.extractFriendlyName(current) ?? defaultLabel,
    );
    final pathController = TextEditingController(
      text: AttachmentUploadHelper.extractUrlOrPath(current),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, color: AppColors.stay, size: 20),
            SizedBox(width: 8),
            Text('Edit Attachment', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('edit_attachment_name_field'),
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Friendly Name',
                hintText: 'e.g. Boarding Pass, eVisa, Ticket Receipt',
                prefixIcon: Icon(Icons.label_outline_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('edit_attachment_path_field'),
              controller: pathController,
              decoration: const InputDecoration(
                labelText: 'File URL / Path *',
                prefixIcon: Icon(Icons.description_outlined, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final path = pathController.text.trim();
              if (path.isNotEmpty) {
                final entry = AttachmentUploadHelper.encodeNamedEntry(
                  urlOrPath: path,
                  friendlyName: nameController.text.trim(),
                );
                final updated = List<String>.from(widget.attachments);
                updated[index] = entry;
                widget.onAttachmentsChanged(updated);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadFile() async {
    setState(() {
      _isUploading = true;
      _uploadStatusMessage = 'Selecting and uploading file...';
    });
    try {
      final downloadUrl = await AttachmentUploadHelper.pickAndUploadFile(
        tripId: widget.tripId,
      );
      if (downloadUrl != null && downloadUrl.isNotEmpty && mounted) {
        final defaultName =
            AttachmentUploadHelper.formatAttachmentLabel(downloadUrl);
        final friendlyName = await _promptFriendlyName(
          title: 'Name Uploaded File',
          defaultName: defaultName,
        );
        final entry = AttachmentUploadHelper.encodeNamedEntry(
          urlOrPath: downloadUrl,
          friendlyName: friendlyName ?? defaultName,
        );
        final updated = List<String>.from(widget.attachments)..add(entry);
        widget.onAttachmentsChanged(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File attached successfully!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not upload file: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatusMessage = '';
        });
      }
    }
  }

  Future<void> _pasteAndUploadImage() async {
    setState(() {
      _isUploading = true;
      _uploadStatusMessage = 'Reading clipboard and uploading image...';
    });
    try {
      final downloadUrl = await AttachmentUploadHelper.pasteAndUploadImage(
        tripId: widget.tripId,
      );
      if (downloadUrl != null && downloadUrl.isNotEmpty && mounted) {
        final defaultName =
            AttachmentUploadHelper.formatAttachmentLabel(downloadUrl);
        final friendlyName = await _promptFriendlyName(
          title: 'Name Pasted Image',
          defaultName: defaultName,
        );
        final entry = AttachmentUploadHelper.encodeNamedEntry(
          urlOrPath: downloadUrl,
          friendlyName: friendlyName ?? defaultName,
        );
        final updated = List<String>.from(widget.attachments)..add(entry);
        widget.onAttachmentsChanged(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image pasted and attached successfully!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No image found on clipboard. Please copy an image first.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not paste image: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatusMessage = '';
        });
      }
    }
  }

  Future<void> _openLink(String raw) async {
    try {
      final url = AttachmentUploadHelper.extractUrlOrPath(raw);
      final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Notes text field
        TextField(
          controller: widget.notesController,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: widget.notesLabel ?? 'Notes',
            hintText: widget.notesHint ??
                'Enter notes, tips, confirmation details, or instructions...',
            prefixIcon: const Icon(Icons.note_alt_outlined, size: 18),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),

        // Links Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Links (${widget.links.length})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _showAddLinkDialog,
              icon: const Icon(Icons.add, size: 15),
              label: const Text('Add Link', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),

        // Links List
        if (widget.links.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (int i = 0; i < widget.links.length; i++)
                Container(
                  key: ValueKey('link_chip_$i'),
                  constraints: const BoxConstraints(maxWidth: 320),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        key: ValueKey('link_chip_edit_$i'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _showEditLinkDialog(i),
                        child: const Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Icon(Icons.edit_outlined,
                              size: 13, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () => _openLink(widget.links[i]),
                          child: Text(
                            AttachmentUploadHelper.formatLinkLabel(widget.links[i]),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        key: ValueKey('link_chip_delete_$i'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          final updated = List<String>.from(widget.links)
                            ..removeAt(i);
                          widget.onLinksChanged(updated);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Icon(Icons.close, size: 14, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        // Attachments Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.stay),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Attachments (${widget.attachments.length})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  key: const ValueKey('attachment_upload_button'),
                  onPressed: _isUploading ? null : _pickAndUploadFile,
                  icon: const Icon(Icons.upload_file_rounded, size: 15),
                  label: const Text('Upload', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('attachment_paste_button'),
                  onPressed: _isUploading ? null : _pasteAndUploadImage,
                  icon: const Icon(Icons.content_paste_rounded, size: 15),
                  label: const Text('Paste', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 16),
                  tooltip: 'More attachment options',
                  padding: EdgeInsets.zero,
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'upload',
                      child: Row(
                        children: [
                          Icon(Icons.upload_file_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('Upload from device'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'paste',
                      child: Row(
                        children: [
                          Icon(Icons.content_paste_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('Paste image from clipboard'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'manual',
                      child: Row(
                        children: [
                          Icon(Icons.edit_note_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('Enter name/URL manually'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (val) {
                    if (val == 'upload') {
                      _pickAndUploadFile();
                    } else if (val == 'paste') {
                      _pasteAndUploadImage();
                    } else if (val == 'manual') {
                      _showAddAttachmentDialog();
                    }
                  },
                ),
              ],
            ),
          ],
        ),

        // Upload progress indicator
        if (_isUploading) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _uploadStatusMessage,
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Attachments List
        if (widget.attachments.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (int i = 0; i < widget.attachments.length; i++)
                Container(
                  key: ValueKey('attachment_chip_$i'),
                  constraints: const BoxConstraints(maxWidth: 320),
                  decoration: BoxDecoration(
                    color: AppColors.stayContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.stay.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        key: ValueKey('attachment_chip_edit_$i'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _showEditAttachmentDialog(i),
                        child: const Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Icon(Icons.edit_outlined,
                              size: 13, color: AppColors.stay),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: AttachmentUploadHelper.isUrl(widget.attachments[i])
                              ? () => AttachmentUploadHelper.openAttachment(
                                    widget.attachments[i],
                                    context,
                                  )
                              : () => _showEditAttachmentDialog(i),
                          child: Text(
                            AttachmentUploadHelper.formatAttachmentLabel(
                              widget.attachments[i],
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              decoration:
                                  AttachmentUploadHelper.isUrl(widget.attachments[i])
                                      ? TextDecoration.underline
                                      : null,
                              color:
                                  AttachmentUploadHelper.isUrl(widget.attachments[i])
                                      ? AppColors.stay
                                      : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        key: ValueKey('attachment_chip_delete_$i'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          final updated = List<String>.from(widget.attachments)
                            ..removeAt(i);
                          widget.onAttachmentsChanged(updated);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Icon(Icons.close, size: 14, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
