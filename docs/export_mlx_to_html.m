top_path = mfilename('fullpath');
top_path(end - length(mfilename):end) =  [];
src_dir = fullfile(top_path, 'mat_source');
html_dir = fullfile(top_path, 'mat_html');
fnames = {'gettingStarted.mlx', 'userUlft.mlx'};
ls(src_dir)
ls(html_dir)
for i = 1:length(fnames)
    disp(i)
    src_name = fullfile(src_dir, fnames{i});
    html_name = fullfile(html_dir, [fnames{i}(1:end - 3), 'pdf']);
    export(src_name, html_name)
end
