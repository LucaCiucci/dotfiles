# dotfiles
My (public) dotfiles

## Use

```sh
git pull
git submodule update --init --recursive
stow .
```

## Track a file

```sh
mv ~/.file .
git add .file
stow .
```

