import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/data/database.dart';
import '../../core/data/m3u_parser.dart';
import '../../core/data/m3u_url_parser.dart';
import '../../core/data/playlist_manager.dart';
import '../../core/data/xtream_importer.dart';
import '../../core/theme/app_colors.dart';

/// The user-selected import method.
enum ImportType {
  /// Standard M3U playlist URL.
  m3u,

  /// Xtream Codes: base URL + username + password.
  xtream,
}

/// Playlist import screen.
///
/// Users can choose between M3U URL or Xtream Codes import, select which
/// content types to import, view existing playlists, and remove them.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => ImportScreenState();
}

@visibleForTesting
class ImportScreenState extends State<ImportScreen> {
  // --- Text controllers -------------------------------------------------------
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // --- State ------------------------------------------------------------------
  final _db = AppDatabase();
  late final PlaylistManager _playlistManager;
  List<Playlist> _playlists = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _importProgressMessage = '';

  /// Which import method the user has selected (defaults to M3U).
  ImportType _importType = ImportType.m3u;

  /// Stream type selection.
  bool _importLive = true;
  bool _importMovies = true;
  bool _importSeries = true;
  bool _importRadio = false;

  @override
  void initState() {
    super.initState();
    _playlistManager = PlaylistManager(database: _db);
    _loadPlaylists();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data operations
  // ---------------------------------------------------------------------------

  Future<void> _loadPlaylists() async {
    final playlists = await _playlistManager.getPlaylists();
    if (mounted) {
      setState(() => _playlists = playlists);
    }
  }

  Future<void> _addPlaylist() async {
    // Clear previous error.
    setState(() => _errorMessage = null);

    // --- Validate inputs based on selected import type ------------------------
    if (_importType == ImportType.m3u) {
      final url = _urlController.text.trim();
      if (url.isEmpty) {
        setState(() => _errorMessage = 'Please enter an M3U URL');
        return;
      }
    } else {
      // Xtream Codes validation.
      final url = _urlController.text.trim();
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      if (url.isEmpty) {
        setState(() => _errorMessage = 'Please enter the server URL');
        return;
      }
      if (username.isEmpty) {
        setState(() => _errorMessage = 'Please enter your username');
        return;
      }
      if (password.isEmpty) {
        setState(() => _errorMessage = 'Please enter your password');
        return;
      }
    }

    // --- Validate content type selection --------------------------------------
    if (_importType == ImportType.xtream) {
      if (!_importLive && !_importMovies && !_importSeries) {
        setState(
            () => _errorMessage = 'Please select at least one content type');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _importProgressMessage = 'Starting import...';
    });

    try {
      if (_importType == ImportType.xtream) {
        await _importXtream();
      } else {
        await _importM3u();
      }

      _urlController.clear();
      _usernameController.clear();
      _passwordController.clear();
      await _loadPlaylists();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Import failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _importProgressMessage = '';
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Xtream import
  // ---------------------------------------------------------------------------

  Future<void> _importXtream() async {
    final rawUrl = _urlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    // Extract base URL: strip path/query if the user pasted a full
    // get.php URL, otherwise use the URL as-is.
    String baseUrl;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      throw const FormatException('Invalid server URL');
    }
    // If the URL has query params with username/password (get.php style),
    // strip everything except scheme/host/port.
    if (uri.queryParameters.containsKey('username') ||
        uri.queryParameters.containsKey('password')) {
      baseUrl = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
      ).toString();
    } else {
      // User entered a clean base URL like http://server.com:8080
      // Strip trailing slashes.
      baseUrl = rawUrl.replaceAll(RegExp(r'/+$'), '');
    }

    // ignore: avoid_print
    print('[Import] Xtream import: baseUrl=$baseUrl user=$username');

    final importer = XtreamImporter(db: _db);
    try {
      // Build the set of selected content types.
      final selectedTypes = <XtreamContentType>{};
      if (_importLive) selectedTypes.add(XtreamContentType.live);
      if (_importMovies) selectedTypes.add(XtreamContentType.vod);
      if (_importSeries) selectedTypes.add(XtreamContentType.series);

      // Create the playlist record via PlaylistManager (encrypted, with user_id).
      // ignore: avoid_print
      print('[Import] Creating playlist record...');
      final playlist = await _playlistManager.addPlaylist(
        '$username@$baseUrl',
        baseUrl,
        username: username,
        password: password,
      );
      // ignore: avoid_print
      print('[Import] Playlist created: id=${playlist.id}');

      // ignore: avoid_print
      print('[Import] Starting XtreamImporter.import()...');
      final result = await importer.import(
        playlistId: playlist.id,
        baseUrl: baseUrl,
        username: username,
        password: password,
        importTypes: selectedTypes,
        onProgress: (message, progress) {
          if (mounted) {
            setState(() => _importProgressMessage = message);
          }
        },
      );

      // ignore: avoid_print
      print('[Import] Done: ch=${result.channels} vod=${result.vodItems} '
          'series=${result.series} error=${result.error}');

      if (mounted) {
        _showImportSummary(
          channels: result.channels,
          vodItems: result.vodItems,
          series: result.series,
          radio: result.radio,
          error: result.error,
        );
      }
    } finally {
      importer.close();
    }
  }

  // ---------------------------------------------------------------------------
  // M3U import
  // ---------------------------------------------------------------------------

  Future<void> _importM3u() async {
    final url = _urlController.text.trim();

    // Auto-detect if the URL is actually an Xtream get.php URL.
    final urlInfo = M3uUrlParser.parse(url);
    if (urlInfo.isXtream) {
      // Switch to Xtream flow using parsed credentials.
      _usernameController.text = urlInfo.username ?? '';
      _passwordController.text = urlInfo.password ?? '';
      if (mounted) {
        setState(() => _importType = ImportType.xtream);
      }
      await _importXtream();
      return;
    }

    if (mounted) {
      setState(() => _importProgressMessage = 'Fetching playlist...');
    }

    final response = await http.get(Uri.parse(url)).timeout(
          const Duration(seconds: 30),
        );
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    if (mounted) {
      setState(() => _importProgressMessage = 'Parsing playlist...');
    }

    final result = M3uParser.parse(response.body);

    if (result.totalItems == 0) {
      throw Exception('No items found in playlist');
    }

    // Apply content type filter.
    final channels = _importLive ? result.channels : <M3uChannel>[];
    final vodItems = _importMovies ? result.vodItems : <M3uVodItem>[];
    final seriesList = _importSeries ? result.series : <M3uSeries>[];
    final radioStations = _importRadio ? result.radioStations : <M3uRadioStation>[];

    // Create playlist record via PlaylistManager (encrypted, with user_id).
    final playlist = await _playlistManager.addPlaylist(
      'Playlist ${_playlists.length + 1}',
      url,
    );

    if (mounted) {
      setState(() => _importProgressMessage = 'Saving channels...');
    }

    // Batch insert channels.
    for (final ch in channels) {
      await _db.into(_db.channels).insert(
            ChannelsCompanion.insert(
              playlistId: playlist.id,
              name: ch.name,
              logo: drift.Value(ch.logo),
              url: ch.url,
              groupTitle: drift.Value(ch.groupTitle),
              tvgName: drift.Value(ch.tvgName),
            ),
          );
    }

    if (mounted) {
      setState(() => _importProgressMessage = 'Saving movies...');
    }

    // Batch insert VOD items.
    for (final vod in vodItems) {
      await _db.into(_db.vodItems).insert(
            VodItemsCompanion.insert(
              playlistId: playlist.id,
              title: vod.title,
              poster: drift.Value(vod.poster),
              url: vod.url,
              groupTitle: drift.Value(vod.groupTitle),
            ),
          );
    }

    if (mounted) {
      setState(() => _importProgressMessage = 'Saving series...');
    }

    // Batch insert series + episodes.
    for (final s in seriesList) {
      final seriesId = await _db.into(_db.tvSeries).insert(
            TvSeriesCompanion.insert(
              playlistId: playlist.id,
              title: s.title,
              poster: drift.Value(s.poster),
            ),
          );
      for (final ep in s.episodes) {
        await _db.into(_db.episodes).insert(
              EpisodesCompanion.insert(
                seriesId: seriesId,
                season: ep.season,
                episode: ep.episode,
                title: ep.title,
                url: ep.url,
                thumbnail: drift.Value(ep.thumbnail),
              ),
            );
      }
    }

    if (mounted) {
      setState(() => _importProgressMessage = 'Saving radio stations...');
    }

    // Batch insert radio stations.
    for (final radio in radioStations) {
      await _db.into(_db.radioStations).insert(
            RadioStationsCompanion.insert(
              playlistId: playlist.id,
              name: radio.name,
              logo: drift.Value(radio.logo),
              url: radio.url,
            ),
          );
    }

    if (mounted) {
      _showImportSummary(
        channels: channels.length,
        vodItems: vodItems.length,
        series: seriesList.length,
        radio: radioStations.length,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Import summary dialog
  // ---------------------------------------------------------------------------

  void _showImportSummary({
    required int channels,
    required int vodItems,
    required int series,
    required int radio,
    String? error,
  }) {
    final hasContent = channels + vodItems + series + radio > 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Row(
          children: [
            Icon(
              hasContent ? Icons.check_circle : Icons.info_outline,
              color: hasContent ? Colors.greenAccent : AppColors.accentPrimary,
            ),
            const SizedBox(width: 12),
            Text(
              hasContent ? 'Import Complete' : 'No Content Found',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (channels > 0) _summaryRow(Icons.live_tv, 'Live TV', channels),
            if (vodItems > 0) _summaryRow(Icons.movie, 'Movies', vodItems),
            if (series > 0) _summaryRow(Icons.tv, 'Series', series),
            if (radio > 0) _summaryRow(Icons.radio, 'Radio', radio),
            if (!hasContent)
              const Text(
                'No items were found for the selected content types.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                'Note: Some categories failed to load.',
                style: TextStyle(
                  color: Colors.orangeAccent.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Navigate back to home after dismissing summary.
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text(
              'OK',
              style: TextStyle(color: AppColors.accentPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accentPrimary, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
          const Spacer(),
          Text(
            '$count',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Playlist management
  // ---------------------------------------------------------------------------

  Future<void> _removePlaylist(Playlist playlist) async {
    await _playlistManager.deletePlaylist(playlist.id);
    await _loadPlaylists();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgElevated,
        title: const Text(
          'Import Playlists',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: FocusTraversalGroup(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // -- Import type selector ----------------------------------------
              _buildImportTypeSelector(),
              const SizedBox(height: 16),

              // -- Input fields (conditional on import type) -------------------
              _buildInputFields(),
              const SizedBox(height: 16),

              // -- Stream type checkboxes --------------------------------------
              _buildStreamTypeCheckboxes(),
              const SizedBox(height: 16),

              // -- Import progress ---------------------------------------------
              if (_isLoading && _importProgressMessage.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    backgroundColor: AppColors.bgSurface,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.accentPrimary),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _importProgressMessage,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // -- Add button -------------------------------------------------
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addPlaylist,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _isLoading ? 'Importing...' : 'Add Playlist',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // -- Error message -----------------------------------------------
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
              ],

              const SizedBox(height: 24),

              // -- Imported playlists header ------------------------------------
              const Text(
                'Imported Playlists',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // -- Playlist list ------------------------------------------------
              _playlists.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No playlists imported yet.\nAdd a playlist above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = _playlists[index];
                        return _buildPlaylistTile(playlist);
                      },
                    ),

              const SizedBox(height: 12),

              // -- Skip button (navigate to home) ------------------------------
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.bgSurface),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Skip for now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Import type selector (toggle at the top)
  // ---------------------------------------------------------------------------

  Widget _buildImportTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeTab(
              label: 'M3U URL',
              icon: Icons.link,
              type: ImportType.m3u,
            ),
          ),
          Expanded(
            child: _buildTypeTab(
              label: 'Xtream Codes',
              icon: Icons.dns,
              type: ImportType.xtream,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab({
    required String label,
    required IconData icon,
    required ImportType type,
  }) {
    final isSelected = _importType == type;
    return GestureDetector(
      onTap: () {
        if (_importType != type) {
          setState(() {
            _importType = type;
            _errorMessage = null;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentPrimary.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(
                  color: AppColors.accentPrimary.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color:
                  isSelected ? AppColors.accentPrimary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.accentPrimary
                    : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Input fields (changes based on import type)
  // ---------------------------------------------------------------------------

  Widget _buildInputFields() {
    if (_importType == ImportType.m3u) {
      return _buildM3UFields();
    } else {
      return _buildXtreamFields();
    }
  }

  Widget _buildM3UFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _urlController,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'M3U URL',
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            hintText: 'https://example.com/playlist.m3u',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.bgSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(
              Icons.link,
              color: AppColors.accentPrimary,
              size: 20,
            ),
            suffixIcon: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentPrimary,
                      ),
                    ),
                  )
                : null,
          ),
          onSubmitted: (_) => _addPlaylist(),
        ),
      ],
    );
  }

  Widget _buildXtreamFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Server URL field.
        TextField(
          controller: _urlController,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Server URL',
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            hintText: 'http://server.com:8080',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.bgSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(
              Icons.dns,
              color: AppColors.accentPrimary,
              size: 20,
            ),
          ),
          onSubmitted: (_) => _addPlaylist(),
        ),
        const SizedBox(height: 8),

        // Username field.
        TextField(
          controller: _usernameController,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Username',
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            hintText: 'Enter Xtream username',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.bgSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(
              Icons.person,
              color: AppColors.accentPrimary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Password field.
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            hintText: 'Enter Xtream password',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.bgSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(
              Icons.lock,
              color: AppColors.accentPrimary,
              size: 20,
            ),
            suffixIcon: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentPrimary,
                      ),
                    ),
                  )
                : null,
          ),
          onSubmitted: (_) => _addPlaylist(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Stream type checkboxes (always visible)
  // ---------------------------------------------------------------------------

  Widget _buildStreamTypeCheckboxes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Content to import',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildContentTypeChip(
              label: 'Live TV',
              icon: Icons.live_tv,
              value: _importLive,
              onChanged: (v) => setState(() => _importLive = v),
            ),
            _buildContentTypeChip(
              label: 'Movies',
              icon: Icons.movie,
              value: _importMovies,
              onChanged: (v) => setState(() => _importMovies = v),
            ),
            _buildContentTypeChip(
              label: 'Series',
              icon: Icons.tv,
              value: _importSeries,
              onChanged: (v) => setState(() => _importSeries = v),
            ),
            _buildContentTypeChip(
              label: 'Radio',
              icon: Icons.radio,
              value: _importRadio,
              onChanged: (v) => setState(() => _importRadio = v),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Playlist tile
  // ---------------------------------------------------------------------------

  Widget _buildPlaylistTile(Playlist playlist) {
    // Decrypt the URL for display.
    final displayUrl = _playlistManager.getDecryptedUrl(playlist);
    return Card(
      color: AppColors.bgElevated,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: const Icon(
          Icons.playlist_play,
          color: AppColors.accentPrimary,
          size: 32,
        ),
        title: Text(
          playlist.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          displayUrl,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.select) {
              _confirmRemove(playlist);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _confirmRemove(playlist),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Content type chip
  // ---------------------------------------------------------------------------

  Widget _buildContentTypeChip({
    required String label,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: value ? AppColors.textPrimary : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: value,
      onSelected: onChanged,
      backgroundColor: AppColors.bgSurface,
      selectedColor: AppColors.accentPrimary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.accentPrimary,
      labelStyle: TextStyle(
        color: value ? AppColors.textPrimary : AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      side: BorderSide(
        color: value
            ? AppColors.accentPrimary.withValues(alpha: 0.5)
            : AppColors.bgSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }

  // ---------------------------------------------------------------------------
  // Confirm remove dialog
  // ---------------------------------------------------------------------------

  void _confirmRemove(Playlist playlist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text(
          'Remove Playlist',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Remove "${playlist.name}" and all its content?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _removePlaylist(playlist);
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
